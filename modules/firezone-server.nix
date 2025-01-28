{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    attrNames
    boolToString
    concatLines
    filterAttrs
    forEach
    getExe
    isBool
    mapAttrs
    mapAttrsToList
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    subtractLists
    types
    ;

  cfg = config.services.firezone.server;

  # All non-secret environment variables or the given component
  collectEnvironment =
    component:
    mapAttrs (_: v: if isBool v then boolToString v else toString v) (
      cfg.settings // cfg.${component}.settings
    );

  # All mandatory secrets which were not explicitly provided by the user will
  # have to be generated, if they do not yet exist.
  generateSecrets =
    let
      requiredSecrets = filterAttrs (_: v: v == null) cfg.settingsSecret;
    in
    ''
      mkdir -p secrets
      chmod 700 secrets
    ''
    + concatLines (
      forEach (attrNames requiredSecrets) (secret: ''
        if [[ ! -e secrets/${secret} ]]; then
          echo "Generating ${secret}"
          # Some secrets like TOKENS_KEY_BASE require a value >=64 bytes.
          head -c 64 /dev/urandom | base64 -w 0 > secrets/${secret}
          chmod 600 secrets/${secret}
        fi
      '')
    );

  # All secrets given in `cfg.settingsSecret` must be loaded from a file and
  # exported into the environment. Also exclude any variables that were
  # overwritten by the local component settings.
  loadSecretEnvironment =
    component:
    let
      relevantSecrets = subtractLists (attrNames cfg.${component}.settings) (
        attrNames cfg.settingsSecret
      );
    in
    concatLines (
      forEach relevantSecrets (secret: ''
        export ${secret}=$(< ${
          if cfg.settingsSecret.${secret} == null then
            "secrets/${secret}"
          else
            "\"$CREDENTIALS_DIRECTORY/${secret}\""
        })
      '')
    );

  commonServiceConfig = {
    # AmbientCapablities = "CAP_NET_ADMIN";
    # CapabilityBoundingSet = "CAP_CHOWN CAP_NET_ADMIN";
    # DeviceAllow = "/dev/net/tun";
    # LockPersonality = "true";
    # LogsDirectory = "dev.firezone.client";
    # LogsDirectoryMode = "755";
    # MemoryDenyWriteExecute = "true";
    # NoNewPrivileges = "true";
    # PrivateMounts = "true";
    # PrivateTmp = "true";
    # PrivateUsers = "false";
    # ProcSubset = "pid";
    # ProtectClock = "true";
    # ProtectControlGroups = "true";
    # ProtectHome = "true";
    # ProtectHostname = "true";
    # ProtectKernelLogs = "true";
    # ProtectKernelModules = "true";
    # ProtectKernelTunables = "true";
    # ProtectProc = "invisible";
    # ProtectSystem = "strict";
    # RestrictAddressFamilies = [
    #   "AF_INET"
    #   "AF_INET6"
    #   "AF_NETLINK"
    #   "AF_UNIX"
    # ];
    # RestrictNamespaces = "true";
    # RestrictRealtime = "true";
    # RestrictSUIDSGID = "true";
    # SystemCallArchitectures = "native";
    # SystemCallFilter = "@aio @basic-io @file-system @io-event @ipc @network-io @signal @system-service";
    # UMask = "077";

    DynamicUser = true;
    User = "firezone";

    Slice = "system-firezone.slice";
    StateDirectory = "firezone";
    WorkingDirectory = "/var/lib/firezone";

    LoadCredential = mapAttrsToList (secretName: secretFile: "${secretName}:${secretFile}") (
      filterAttrs (_: v: v != null) cfg.settingsSecret
    );
  };

  componentOptions = component: {
    enable = mkEnableOption "the Firezone ${component} server";
    # TODO: single package plus web and api passthrough.
    # package = mkPackageOption pkgs "firezone-server" { };

    settings = lib.mkOption {
      description = ''
        Environment variables for this component of the Firezone server. For a
        list of available variables, please refer to the [upstream definitions](https://github.com/firezone/firezone/blob/main/elixir/apps/domain/lib/domain/config/definitions.ex).
        Some variables like `OUTBOUND_EMAIL_ADAPTER_OPTS` require json values
        for which you can use `VAR = builtins.toJSON { /* ... */ }`.

        This component will automatically inherit all variables defined via
        {option}`services.firezone.server.settings` and
        {option}`services.firezone.server.settingsSecret`, but which can be
        overwritten by this option.
      '';
      default = { };
      type = lib.types.submodule {
        freeformType = types.attrsOf (
          types.oneOf [
            types.bool
            types.float
            types.int
            types.str
            types.path
            types.package
          ]
        );
      };
    };
  };
in
{
  options.services.firezone.server = {
    enable = mkEnableOption "all Firezone components";
    enableLocalDB = mkEnableOption "a local postgresql database for Firezone";

    nginx = {
      enable = mkEnableOption "nginx virtualhost definition";
      apiDomain = mkOption {
        type = types.str;
        example = "api.firezone.example.com";
        description = "The virtual host domain under which the api should be exposed";
      };
      webDomain = mkOption {
        type = types.str;
        example = "firezone.example.com";
        description = "The virtual host domain under which the web interface should be exposed";
      };
    };

    openClusterFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Opens up the erlang distribution port of all enabled components to
        allow reaching the server cluster from the internet. You only need to
        set this if you are actually distributing your cluster across multiple
        machines.
      '';
    };

    clusterHosts = mkOption {
      type = types.listOf types.str;
      default = [
        "api@localhost.localdomain"
        "web@localhost.localdomain"
        "domain@localhost.localdomain"
      ];
      description = ''
        A list of components and their hosts that are part of this cluster. For
        a single-machine setup, the default value will be sufficient. This
        value will automatically set `ERLANG_CLUSTER_ADAPTER_CONFIG`.

        The format is `<COMPONENT_NAME>@<HOSTNAME>`.
      '';
    };

    settingsSecret = mkOption {
      default = { };
      description = ''
        This is a convenience option which allows you to set secret values for
        environment variables by specifying a file which will contain the value
        at runtime. Before starting the server, the content of each file will
        be loaded into the respective environment variable.

        Otherwise, this option is equivalent to
        {option}`services.firezone.server.settings`. Refer to the settings
        option for more information regarding the actual variables and how
        filtering rules are applied for each component.
      '';
      type = lib.types.submodule {
        freeformType = types.attrsOf types.path;
        options = {
          RELEASE_COOKIE = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              A file containing a unique secret identifier for the Erlang
              cluster. All Firezone components in your cluster must use the
              same value.

              If this is `null`, a shared value will automatically be generated
              on startup and used for all components on this machine. You do
              not need to set this except when you spread your cluster over
              multiple hosts.
            '';
          };

          TOKENS_KEY_BASE = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              A file containing a unique base64 encoded secret for the
              `TOKENS_KEY_BASE`. All Firezone components in your cluster must
              use the same value.

              If this is `null`, a shared value will automatically be generated
              on startup and used for all components on this machine. You do
              not need to set this except when you spread your cluster over
              multiple hosts.
            '';
          };

          SECRET_KEY_BASE = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              A file containing a unique base64 encoded secret for the
              `SECRET_KEY_BASE`. All Firezone components in your cluster must
              use the same value.

              If this is `null`, a shared value will automatically be generated
              on startup and used for all components on this machine. You do
              not need to set this except when you spread your cluster over
              multiple hosts.
            '';
          };

          TOKENS_SALT = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              A file containing a unique base64 encoded secret for the
              `TOKENS_SALT`. All Firezone components in your cluster must
              use the same value.

              If this is `null`, a shared value will automatically be generated
              on startup and used for all components on this machine. You do
              not need to set this except when you spread your cluster over
              multiple hosts.
            '';
          };

          LIVE_VIEW_SIGNING_SALT = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              A file containing a unique base64 encoded secret for the
              `LIVE_VIEW_SIGNING_SALT`. All Firezone components in your cluster must
              use the same value.

              If this is `null`, a shared value will automatically be generated
              on startup and used for all components on this machine. You do
              not need to set this except when you spread your cluster over
              multiple hosts.
            '';
          };

          COOKIE_SIGNING_SALT = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              A file containing a unique base64 encoded secret for the
              `COOKIE_SIGNING_SALT`. All Firezone components in your cluster must
              use the same value.

              If this is `null`, a shared value will automatically be generated
              on startup and used for all components on this machine. You do
              not need to set this except when you spread your cluster over
              multiple hosts.
            '';
          };

          COOKIE_ENCRYPTION_SALT = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              A file containing a unique base64 encoded secret for the
              `COOKIE_ENCRYPTION_SALT`. All Firezone components in your cluster must
              use the same value.

              If this is `null`, a shared value will automatically be generated
              on startup and used for all components on this machine. You do
              not need to set this except when you spread your cluster over
              multiple hosts.
            '';
          };
        };
      };
    };

    settings = lib.mkOption {
      description = ''
        Environment variables for the Firezone server. For a list of available
        variables, please refer to the [upstream definitions](https://github.com/firezone/firezone/blob/main/elixir/apps/domain/lib/domain/config/definitions.ex).
        Some variables like `OUTBOUND_EMAIL_ADAPTER_OPTS` require json values
        for which you can use `VAR = builtins.toJSON { /* ... */ }`.

        Each component has an additional `settings` option which allows you to
        override specific variables passed to that component.
      '';
      default = { };
      type = lib.types.submodule {
        freeformType = types.attrsOf (
          types.oneOf [
            types.bool
            types.float
            types.int
            types.str
            types.path
            types.package
          ]
        );
      };
    };

    domain = componentOptions "domain";

    web = componentOptions "web" // {
      externalUrl = mkOption {
        type = types.strMatching "^https://.+/$";
        example = "https://firezone.example.com/";
        description = ''
          The external URL under which you will serve the web interface. You
          need to setup a reverse proxy for TLS termination, either with
          {option}`services.firezone.server.nginx.enable` or manually.
        '';
      };

      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "The address to listen on";
      };

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "The port under which the web interface will be served locally";
      };

      trustedProxies = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "A list of trusted proxies";
      };
    };

    api = componentOptions "api" // {
      externalUrl = mkOption {
        type = types.strMatching "^https://.+/$";
        example = "https://api.firezone.example.com/";
        description = ''
          The external URL under which you will serve the api. You need to
          setup a reverse proxy for TLS termination, either with
          {option}`services.firezone.server.nginx.enable` or manually.
        '';
      };

      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "The address to listen on";
      };

      port = mkOption {
        type = types.port;
        default = 8081;
        description = "The port under which the api will be served locally";
      };

      trustedProxies = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "A list of trusted proxies";
      };
    };
  };

  config = mkMerge [
    # Enable all components if the main server is enabled
    (mkIf cfg.enable {
      services.firezone.server.domain.enable = true;
      services.firezone.server.web.enable = true;
      services.firezone.server.api.enable = true;
    })
    # Create (and configure) a local database if desired
    (mkIf cfg.enableLocalDB {
      services.postgresql = {
        enable = true;
        ensureUsers = [
          {
            name = "firezone";
            ensureDBOwnership = true;
          }
        ];
        ensureDatabases = [ "firezone" ];
      };

      services.firezone.server.settings = {
        DATABASE_SOCKET_DIR = "/run/postgresql";
        DATABASE_PORT = "5432";
        DATABASE_NAME = "firezone";
        DATABASE_USER = "firezone";
      };
    })
    # Create a local nginx reverse proxy
    (mkIf cfg.nginx.enable {
      services.nginx = {
        enable = true;
        virtualHosts.${cfg.nginx.webDomain} = {
          forceSSL = mkDefault true;
          locations."/" = {
            proxyPass = "http://${cfg.dashboardAddress}";
            proxyWebsockets = true;
          };
        };
        virtualHosts.${cfg.nginx.apiDomain} = {
          forceSSL = mkDefault true;
          locations."/" = {
            proxyPass = "http://${cfg.dashboardAddress}";
            proxyWebsockets = true;
          };
        };
      };
    })
    # Specify sensible defaults
    {
      services.firezone.server = {
        settings = {
          LOG_LEVEL = mkDefault "debug";
          RELEASE_HOSTNAME = mkDefault "localhost.localdomain";

          ERLANG_CLUSTER_ADAPTER = mkDefault "Elixir.Cluster.Strategy.Epmd";
          ERLANG_CLUSTER_ADAPTER_CONFIG = mkDefault (
            builtins.toJSON {
              hosts = cfg.clusterHosts;
            }
          );

          TZDATA_DIR = mkDefault "/var/lib/firezone/tzdata";
          TELEMETRY_ENABLED = mkDefault false;

          # By default this will open nproc * 2 connections for each component,
          # which can exceeds the (default) maximum of 100 connections for
          # postgresql on a 12 core +SMT machine. 16 connections will be
          # sufficient for small to medium deployments
          DATABASE_POOL_SIZE = "16";

          AUTH_PROVIDER_ADAPTERS = mkDefault "email,openid_connect,userpass,token";

          FEATURE_FLOW_ACTIVITIES_ENABLED = mkDefault true;
          FEATURE_POLICY_CONDITIONS_ENABLED = mkDefault true;
          FEATURE_MULTI_SITE_RESOURCES_ENABLED = mkDefault true;
          FEATURE_SELF_HOSTED_RELAYS_ENABLED = mkDefault true;
          FEATURE_IDP_SYNC_ENABLED = mkDefault true;
          FEATURE_REST_API_ENABLED = mkDefault true;
          FEATURE_INTERNET_RESOURCE_ENABLED = mkDefault true;
          FEATURE_TRAFFIC_FILTERS_ENABLED = mkDefault true;
          FEATURE_SIGN_UP_ENABLED = mkDefault true;
        };

        domain.settings = {
          ERLANG_DISTRIBUTION_PORT = mkDefault 9000;
          HEALTHZ_PORT = mkDefault 4000;
        };

        web.settings = {
          ERLANG_DISTRIBUTION_PORT = mkDefault 9001;
          HEALTHZ_PORT = mkDefault 4001;

          PHOENIX_LISTEN_ADDRESS = mkDefault cfg.web.address;
          PHOENIX_EXTERNAL_TRUSTED_PROXIES = mkDefault (builtins.toJSON cfg.web.trustedProxies);
          PHOENIX_HTTP_WEB_PORT = mkDefault cfg.web.port;
          PHOENIX_HTTP_API_PORT = mkDefault cfg.api.port;
          PHOENIX_SECURE_COOKIES = mkDefault true; # enforce HTTPS on cookies
          WEB_EXTERNAL_URL = mkDefault cfg.web.externalUrl;
          API_EXTERNAL_URL = mkDefault cfg.api.externalUrl;
        };

        api.settings = {
          ERLANG_DISTRIBUTION_PORT = mkDefault 9002;
          HEALTHZ_PORT = mkDefault 4002;

          PHOENIX_LISTEN_ADDRESS = mkDefault cfg.api.address;
          PHOENIX_EXTERNAL_TRUSTED_PROXIES = mkDefault (builtins.toJSON cfg.api.trustedProxies);
          PHOENIX_HTTP_WEB_PORT = mkDefault cfg.web.port;
          PHOENIX_HTTP_API_PORT = mkDefault cfg.api.port;
          PHOENIX_SECURE_COOKIES = mkDefault true; # enforce HTTPS on cookies
          WEB_EXTERNAL_URL = mkDefault cfg.web.externalUrl;
          API_EXTERNAL_URL = mkDefault cfg.api.externalUrl;
        };
      };
    }
    (mkIf (cfg.domain.enable || cfg.web.enable || cfg.api.enable) {
      # FIXME: mkIf openClusterFirewall {};

      systemd.slices.system-firezone = {
        description = "Firezone Slice";
      };

      systemd.targets.firezone = {
        description = "Common target for all Firezone services.";
        wantedBy = [ "multi-user.target" ];
      };

      systemd.services.firezone-initialize = {
        description = "Firezone initialization";

        after = mkIf cfg.enableLocalDB [ "postgresql.service" ];
        requires = mkIf cfg.enableLocalDB [ "postgresql.service" ];
        wantedBy = [ "firezone.target" ];
        partOf = [ "firezone.target" ];

        script = ''
          mkdir -p "$TZDATA_DIR"

          # Generate and load secrets
          ${generateSecrets}
          ${loadSecretEnvironment "domain"}

          echo "Running migrations"
          ${getExe pkgs.firezone-server-domain} eval Domain.Release.migrate

          echo "Provisioning"
        ''; # FIXME: ^----- aaaaaaaaaaaaaaaaaa
        #FIXME: aaaaaaaaaaaaaaaaaa
        #FIXME: aaaaaaaaaaaaaaaaaa
        #FIXME: aaaaaaaaaaaaaaaaaa

        # We use the domain environment to be able to run migrations
        environment = collectEnvironment "domain";
        serviceConfig = commonServiceConfig // {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      systemd.services.firezone-server-domain = mkIf cfg.domain.enable {
        description = "Firezone domain server";
        after = [ "firezone-initialize.service" ];
        bindsTo = [ "firezone-initialize.service" ];
        wantedBy = [ "firezone.target" ];
        partOf = [ "firezone.target" ];

        script = ''
          ${loadSecretEnvironment "domain"}
          exec ${getExe pkgs.firezone-server-domain} start;
        '';

        environment = collectEnvironment "domain";
        serviceConfig = commonServiceConfig;
      };

      systemd.services.firezone-server-web = mkIf cfg.web.enable {
        description = "Firezone web server";
        after = [ "firezone-initialize.service" ];
        bindsTo = [ "firezone-initialize.service" ];
        wantedBy = [ "firezone.target" ];
        partOf = [ "firezone.target" ];

        script = ''
          ${loadSecretEnvironment "web"}
          exec ${getExe pkgs.firezone-server-web} start;
        '';

        environment = collectEnvironment "web";
        serviceConfig = commonServiceConfig;
      };

      systemd.services.firezone-server-api = mkIf cfg.api.enable {
        description = "Firezone api server";
        after = [ "firezone-initialize.service" ];
        bindsTo = [ "firezone-initialize.service" ];
        wantedBy = [ "firezone.target" ];
        partOf = [ "firezone.target" ];

        script = ''
          ${loadSecretEnvironment "api"}
          exec ${getExe pkgs.firezone-server-api} start;
        '';

        environment = collectEnvironment "api";
        serviceConfig = commonServiceConfig;
      };
    })
  ];

  meta.maintainers = with lib.maintainers; [
    oddlama
    patrickdag
  ];
}
