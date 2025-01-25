{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    mkIf
    getExe
    mkEnableOption
    types
    ;

  cfg = config.services.firezone.server;
  apiCfg = config.services.firezone.server.api;
  domainCfg = config.services.firezone.server.domain;
  webCfg = config.services.firezone.server.web;

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

    StateDirectory = "firezone";
    WorkingDirectory = "/var/lib/firezone";
  };

  commonEnv = {
    # **EXTERNAL_URL**
    # PHOENIX_SECURE_COOKIES
    # PHOENIX_HTTP_PORT
    # PHOENIX_HTTP_PROTOCOL_OPTIONS
    # PHOENIX_EXTERNAL_TRUSTED_PROXIES
    # PHOENIX_PRIVATE_CLIENTS
    # HTTP_CLIENT_SSL_OPTS
    # DATABASE_HOST
    # DATABASE_PORT
    # DATABASE_NAME
    # DATABASE_USER
    # DATABASE_PASSWORD
    # DATABASE_POOL_SIZE
    # DATABASE_SSL_ENABLED
    # DATABASE_SSL_OPTS
    # RESET_ADMIN_ON_BOOT
    # DEFAULT_ADMIN_EMAIL
    # DEFAULT_ADMIN_PASSWORD
    # **GUARDIAN_SECRET_KEY**
    # **DATABASE_ENCRYPTION_KEY**
    # **SECRET_KEY_BASE**
    # **LIVE_VIEW_SIGNING_SALT**
    # **COOKIE_SIGNING_SALT**
    # **COOKIE_ENCRYPTION_SALT**
    # ALLOW_UNPRIVILEGED_DEVICE_MANAGEMENT
    # ALLOW_UNPRIVILEGED_DEVICE_CONFIGURATION
    # VPN_SESSION_DURATION
    # DEFAULT_CLIENT_PERSISTENT_KEEPALIVE
    # DEFAULT_CLIENT_MTU
    # DEFAULT_CLIENT_ENDPOINT
    # DEFAULT_CLIENT_DNS
    # DEFAULT_CLIENT_ALLOWED_IPS
    # MAX_DEVICES_PER_USER
    # LOCAL_AUTH_ENABLED
    # DISABLE_VPN_ON_OIDC_ERROR
    # SAML_ENTITY_ID
    # SAML_KEYFILE_PATH
    # SAML_CERTFILE_PATH
    # OPENID_CONNECT_PROVIDERS
    # SAML_IDENTITY_PROVIDERS
    # WIREGUARD_PORT
    # OUTBOUND_EMAIL_FROM
    # OUTBOUND_EMAIL_ADAPTER
    # OUTBOUND_EMAIL_ADAPTER_OPTS
    # CONNECTIVITY_CHECKS_ENABLED
    # CONNECTIVITY_CHECKS_INTERVAL
    # TELEMETRY_ENABLED
    # LOGO

    TZDATA_DIR = "/var/lib/firezone/tzdata";
    TELEMETRY_ENABLED = "false";

    RELEASE_COOKIE = "agfea"; # TODO make option, if null generate automatically on first start

    # Database;
    DATABASE_SOCKET_DIR = "/run/postgresql";
    DATABASE_PORT = "5432";
    DATABASE_NAME = "firezone";
    DATABASE_USER = "firezone";
    DATABASE_POOL_SIZE = "16";
    #DATABASE_HOST = "localhost";
    #DATABASE_PASSWORD = "";

    # Auth;
    AUTH_PROVIDER_ADAPTERS = "email,openid_connect,userpass,token";

    # Secrets;
    TOKENS_KEY_BASE = "5OVYJ83AcoQcPmdKNksuBhJFBhjHD1uUa9mDOHV/6EIdBQ6pXksIhkVeWIzFk5S2";
    SECRET_KEY_BASE = "5OVYJ83AcoQcPmdKNksuBhJFBhjHD1uUa9mDOHV/6EIdBQ6pXksIhkVeWIzFk5S2";
    TOKENS_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
    LIVE_VIEW_SIGNING_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
    COOKIE_SIGNING_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
    COOKIE_ENCRYPTION_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";

    OUTBOUND_EMAIL_ADAPTER = "Elixir.Swoosh.Adapters.Mua";
    OUTBOUND_EMAIL_ADAPTER_OPTS = builtins.toJSON {
    };

    # Feature flags;
    FEATURE_FLOW_ACTIVITIES_ENABLED = "true";
    FEATURE_POLICY_CONDITIONS_ENABLED = "true";
    FEATURE_MULTI_SITE_RESOURCES_ENABLED = "true";
    FEATURE_SELF_HOSTED_RELAYS_ENABLED = "true";
    FEATURE_IDP_SYNC_ENABLED = "true";
    FEATURE_REST_API_ENABLED = "true";
    FEATURE_INTERNET_RESOURCE_ENABLED = "true";
    FEATURE_TRAFFIC_FILTERS_ENABLED = "true";
    FEATURE_SIGN_UP_ENABLED = "true";
  };

  componentOptions = component: {
    enable = mkEnableOption "the Firezone ${component} server";
    # TODO: single package plus web and api passthrough.
    # package = mkPackageOption pkgs "firezone-server" { };

    environment = {
      exclude = mkOption {
        type = types.attrsOf types.bool;
        default = { };
        description = ''
          Each environment variable specified through either
          {option}`services.firezone.server.settings` or
          {option}`services.firezone.server.secretSettings`
          will only be passed to this component if it is not excluded
          by this option.
        '';
        example = {
          PHOENIX_HTTP_PORT = true;
        };
      };

      replaceWithDummy = mkOption {
        type = types.attrsOf types.bool;
        default = { };
        description = ''
          Any environment variable specified here will receive a dummy value
          instead of the actual value specified through either
          {option}`services.firezone.server.settings` or
          {option}`services.firezone.server.secretSettings`.

          This can be used to hide secret information from components that
          require a certain variable to be set while not actually using its
          value.
        '';
        example = {
          SECRET_KEY_BASE = true;
        };
      };

      override = mkOption {
        description = ''
          Any environment variable specified here will receive the associated
          value just for this component instead of the actual value specified
          through either {option}`services.firezone.server.settings` or
          {option}`services.firezone.server.secretSettings`.
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

    settings = lib.mkOption {
      description = ''
        Environment variables for the Firezone server. For a list of available
        variables, please refer to the [upstream definitions](https://github.com/firezone/firezone/blob/main/elixir/apps/domain/lib/domain/config/definitions.ex).
        Some variables like `OUTBOUND_EMAIL_ADAPTER_OPTS` require json values
        for which you can use `VAR = builtins.toJSON { /* ... */ }`.

        Configuration variables in Firezone are generally defined across all
        components, so certain variables need to be present before any componen
        will start up, even if that particular component does not actually
        utilize its value.

        Each component has an additional `environment` option group which
        allows you to exclude, replace or override certain variables passed to
        that component. A sensible default filter is provided which you can
        modify if necessary.
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
    enableLocalDB = mkEnableOption "a local postgresql database for Firezone";
    # FIXME: enableNginx = mkEnableOption "a local nginx endpoint";

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

    secretSettings = mkOption {
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
          # FIXME: SECRET_KEY_BASE
          RELEASE_COOKIE = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              A file containing a unique secret identifier for the Erlang
              cluster. All Firezone components in your cluster must use the
              same value. If this is `null`, a shared value will automatically
              be generated on startup and used for all components on this
              machine.

              You do not need to set this except when you spread your cluster
              over multiple hosts.
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

        Configuration variables in Firezone are generally defined across all
        components, so certain variables need to be present before any componen
        will start up, even if that particular component does not actually
        utilize its value.

        Each component has an additional `environment` option group which
        allows you to exclude, replace or override certain variables passed to
        that component. A sensible default filter is provided which you can
        modify if necessary.
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

    domain = componentOptions "domain" // {
    };
    web = componentOptions "web" // {
    };
    api = componentOptions "api" // {
    };
  };

  config = {
    # Specify sensible defaults
    services.firezone.server = {
      settings = {
        LOG_LEVEL = "debug";
        RELEASE_HOSTNAME = "localhost.localdomain";

        ERLANG_CLUSTER_ADAPTER = "Elixir.Cluster.Strategy.Epmd";
        ERLANG_CLUSTER_ADAPTER_CONFIG = builtins.toJSON {
          hosts = cfg.clusterHosts;
        };

        TZDATA_DIR = "/var/lib/firezone/tzdata";
        TELEMETRY_ENABLED = false;

        WEB_EXTERNAL_URL = "http://localhost:8080/";
        API_EXTERNAL_URL = "http://localhost:8081/";
      };

      domain.settings = {
        ERLANG_DISTRIBUTION_PORT = 9000;
        HEALTHZ_PORT = 4000;
      };
      domain.environment.exclude = {
        WEB_EXTERNAL_URL = true;
        API_EXTERNAL_URL = true;
      };

      web.settings = {
        ERLANG_DISTRIBUTION_PORT = 9001;
        HEALTHZ_PORT = 4001;

        # Web Server
        PHOENIX_HTTP_WEB_PORT = 8080;
        PHOENIX_HTTP_API_PORT = 8081;
        PHOENIX_SECURE_COOKIES = false;
      };

      api.settings = {
        ERLANG_DISTRIBUTION_PORT = 9002;
        HEALTHZ_PORT = 4002;
      };
    };

    # FIXME: mkIf openClusterFirewall {};

    services.postgresql = mkIf cfg.enableLocalDB {
      enable = true;
      ensureUsers = [
        {
          name = "firezone";
          ensureDBOwnership = true;
        }
      ];
      ensureDatabases = [ "firezone" ];
    };

    systemd.services.firezone-server-domain = mkIf domainCfg.enable {
      description = "Firezone domain server";
      after = mkIf cfg.enableLocalDB [ "postgresql.service" ];
      wants = mkIf cfg.enableLocalDB [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p tzdata
      '';

      script = ''
        ${getExe pkgs.firezone-server-domain} eval Domain.Release.migrate
        exec ${getExe pkgs.firezone-server-domain} start
      '';

      serviceConfig = commonServiceConfig // {
      };

      environment = commonEnv // {
        RELEASE_NAME = "domain";
        RELEASE_HOSTNAME = "localhost.localdomain";

        ERLANG_DISTRIBUTION_PORT = "9000";
        HEALTHZ_PORT = "4000";

        RESET_ADMIN_ON_BOOT = "true";
        DEFAULT_ADMIN_EMAIL = "admin@example.com";
        DEFAULT_ADMIN_PASSWORD = "admin@example.com";
      };
    };

    systemd.services.firezone-server-web = mkIf webCfg.enable {
      description = "Firezone web server";
      after = mkIf cfg.enableLocalDB [ "postgresql.service" ];
      wants = mkIf cfg.enableLocalDB [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p tzdata
      '';

      script = ''
        ${getExe pkgs.firezone-server-web} eval Domain.Release.migrate
        exec ${getExe pkgs.firezone-server-web} start
      '';

      serviceConfig = commonServiceConfig // {
      };

      environment = commonEnv // {
        RELEASE_NAME = "web";
        RELEASE_HOSTNAME = "localhost.localdomain";

        ERLANG_DISTRIBUTION_PORT = "9001";
        HEALTHZ_PORT = "4001";

        # Web Server
        WEB_EXTERNAL_URL = "http://localhost:8080/";
        API_EXTERNAL_URL = "http://localhost:8081/";
        PHOENIX_HTTP_WEB_PORT = "8080";
        PHOENIX_HTTP_API_PORT = "8081";
        PHOENIX_SECURE_COOKIES = "false";
      };
    };

    systemd.services.firezone-server-api = mkIf apiCfg.enable {
      description = "Firezone api server";
      after = mkIf cfg.enableLocalDB [ "postgresql.service" ];
      wants = mkIf cfg.enableLocalDB [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p tzdata
      '';

      script = ''
        ${getExe pkgs.firezone-server-api} eval Domain.Release.migrate
        exec ${getExe pkgs.firezone-server-api} start
      '';

      serviceConfig = commonServiceConfig // {
      };

      environment = commonEnv // {
        RELEASE_NAME = "api";
        RELEASE_HOSTNAME = "localhost.localdomain";

        ERLANG_DISTRIBUTION_PORT = "9002";
        HEALTHZ_PORT = "4002";

        # Web Server
        WEB_EXTERNAL_URL = "http://localhost:8080/";
        API_EXTERNAL_URL = "http://localhost:8081/";
      };
    };
  };

  meta.maintainers = with lib.maintainers; [
    oddlama
    patrickdag
  ];
}
