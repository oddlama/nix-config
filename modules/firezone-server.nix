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
in
{
  options.services.firezone.server = {
    domain = {
      enable = mkEnableOption "the Firezone domain server";
      # TODO: single package plus web and api passthrough.
      # package = mkPackageOption pkgs "firezone-server" { };
      enableLocalDB = mkEnableOption "a local postgresql database for Firezone";

      settings = lib.mkOption {
        default = { };
        description = ''
          TODO
        '';
        example = {
        };
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
          options = {
          };
        };
      };
    };
    web = {
      enable = mkEnableOption "the Firezone web server";
      # TODO: single package plus web and api passthrough.
      # package = mkPackageOption pkgs "firezone-server" { };

      settings = lib.mkOption {
        default = { };
        description = ''
          TODO
        '';
        example = {
        };
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
          options = {
          };
        };
      };
    };
    api = {
      enable = mkEnableOption "the Firezone api server";
      # TODO: single package plus web and api passthrough.
      # package = mkPackageOption pkgs "firezone-server" { };

      settings = lib.mkOption {
        default = { };
        description = ''
          TODO
        '';
        example = {
        };
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
          options = {
          };
        };
      };
    };
  };

  config = {
    services.postgresql = mkIf domainCfg.enableLocalDB {
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
      after = mkIf domainCfg.enableLocalDB [ "postgresql.service" ];
      wants = mkIf domainCfg.enableLocalDB [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p tzdata
      '';

      serviceConfig = commonServiceConfig // {
        ExecStart = "${getExe pkgs.firezone-server-domain} start";
      };

      environment = {
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
        RELEASE_NAME = "domain";
        RELEASE_HOSTNAME = "localhost.localdomain";

        HEALTHZ_PORT = "4000";

        # Debugging;
        LOG_LEVEL = "debug";

        # Erlang;
        ERLANG_DISTRIBUTION_PORT = "9002";
        ERLANG_CLUSTER_ADAPTER = "Elixir.Cluster.Strategy.Epmd";
        ERLANG_CLUSTER_ADAPTER_CONFIG = builtins.toJSON {
          hosts = [
            "api@localhost.localdomain"
            "web@localhost.localdomain"
            "domain@localhost.localdomain"
          ];
        };

        # Database;
        DATABASE_SOCKET_DIR = "/run/postgresql";
        DATABASE_PORT = "5432";
        DATABASE_NAME = "firezone";
        DATABASE_USER = "firezone";
        #DATABASE_HOST = "localhost";
        #DATABASE_PASSWORD = "";

        # Auth;
        AUTH_PROVIDER_ADAPTERS = "email,openid_connect,userpass,token,google_workspace,microsoft_entra,okta,jumpcloud";

        # Secrets;
        TOKENS_KEY_BASE = "5OVYJ83AcoQcPmdKNksuBhJFBhjHD1uUa9mDOHV/6EIdBQ6pXksIhkVeWIzFk5S2";
        SECRET_KEY_BASE = "5OVYJ83AcoQcPmdKNksuBhJFBhjHD1uUa9mDOHV/6EIdBQ6pXksIhkVeWIzFk5S2";
        TOKENS_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
        LIVE_VIEW_SIGNING_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
        COOKIE_SIGNING_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
        COOKIE_ENCRYPTION_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";

        # Seeds;
        STATIC_SEEDS = "true";

        OUTBOUND_EMAIL_FROM = "public-noreply@firez.one";
        OUTBOUND_EMAIL_ADAPTER = "Elixir.Swoosh.Adapters.Postmark";
        ## Warning= The token is for the blackhole Postmark server created in a separate isolated account,;
        ## that WILL NOT send any actual emails, but you can see and debug them in the Postmark dashboard.;
        OUTBOUND_EMAIL_ADAPTER_OPTS = ''{"api_key":"7da7d1cd-111c-44a7-b5ac-4027b9d230e5"}'';

        # Feature flags;
        FEATURE_FLOW_ACTIVITIES_ENABLED = "true";
        FEATURE_POLICY_CONDITIONS_ENABLED = "true";
        FEATURE_MULTI_SITE_RESOURCES_ENABLED = "true";
        FEATURE_SELF_HOSTED_RELAYS_ENABLED = "true";
        FEATURE_IDP_SYNC_ENABLED = "true";
        FEATURE_REST_API_ENABLED = "true";
        FEATURE_INTERNET_RESOURCE_ENABLED = "true";
      };
    };

    systemd.services.firezone-server-web = mkIf webCfg.enable {
      description = "Firezone web server";
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p tzdata
      '';

      serviceConfig = commonServiceConfig // {
        ExecStart = "${getExe pkgs.firezone-server-web} start";
      };

      environment = {
        TZDATA_DIR = "/var/lib/firezone/tzdata";
        TELEMETRY_ENABLED = "false";

        RELEASE_COOKIE = "agfea"; # TODO make option, if null generate automatically on first start
        RELEASE_NAME = "web";
        RELEASE_HOSTNAME = "localhost.localdomain";

        # Web Server
        WEB_EXTERNAL_URL = "http://localhost:8080/";
        API_EXTERNAL_URL = "http://localhost:8081/";
        PHOENIX_HTTP_WEB_PORT = "8080";
        PHOENIX_HTTP_API_PORT = "8081";
        PHOENIX_SECURE_COOKIES = "false";

        HEALTHZ_PORT = "4001";

        # Debugging;
        LOG_LEVEL = "debug";

        # Erlang;
        ERLANG_DISTRIBUTION_PORT = "9001";
        ERLANG_CLUSTER_ADAPTER = "Elixir.Cluster.Strategy.Epmd";
        ERLANG_CLUSTER_ADAPTER_CONFIG = builtins.toJSON {
          hosts = [
            "api@localhost.localdomain"
            "web@localhost.localdomain"
            "domain@localhost.localdomain"
          ];
        };

        # Database;
        DATABASE_SOCKET_DIR = "/run/postgresql";
        DATABASE_PORT = "5432";
        DATABASE_NAME = "firezone";
        DATABASE_USER = "firezone";
        #DATABASE_HOST = "localhost";
        #DATABASE_PASSWORD = "";

        # Auth;
        AUTH_PROVIDER_ADAPTERS = "email,openid_connect,userpass,token,google_workspace,microsoft_entra,okta,jumpcloud";

        # Secrets;
        TOKENS_KEY_BASE = "5OVYJ83AcoQcPmdKNksuBhJFBhjHD1uUa9mDOHV/6EIdBQ6pXksIhkVeWIzFk5S2";
        SECRET_KEY_BASE = "5OVYJ83AcoQcPmdKNksuBhJFBhjHD1uUa9mDOHV/6EIdBQ6pXksIhkVeWIzFk5S2";
        TOKENS_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
        LIVE_VIEW_SIGNING_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
        COOKIE_SIGNING_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
        COOKIE_ENCRYPTION_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";

        # Seeds;
        STATIC_SEEDS = "true";

        OUTBOUND_EMAIL_FROM = "public-noreply@firez.one";
        OUTBOUND_EMAIL_ADAPTER = "Elixir.Swoosh.Adapters.Postmark";
        ## Warning= The token is for the blackhole Postmark server created in a separate isolated account,;
        ## that WILL NOT send any actual emails, but you can see and debug them in the Postmark dashboard.;
        OUTBOUND_EMAIL_ADAPTER_OPTS = ''{"api_key":"7da7d1cd-111c-44a7-b5ac-4027b9d230e5"}'';

        # Feature flags;
        FEATURE_FLOW_ACTIVITIES_ENABLED = "true";
        FEATURE_POLICY_CONDITIONS_ENABLED = "true";
        FEATURE_MULTI_SITE_RESOURCES_ENABLED = "true";
        FEATURE_SELF_HOSTED_RELAYS_ENABLED = "true";
        FEATURE_IDP_SYNC_ENABLED = "true";
        FEATURE_REST_API_ENABLED = "true";
        FEATURE_INTERNET_RESOURCE_ENABLED = "true";
      };
    };

    systemd.services.firezone-server-api = mkIf apiCfg.enable {
      description = "Firezone api server";
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p tzdata
      '';

      serviceConfig = commonServiceConfig // {
        ExecStart = "${getExe pkgs.firezone-server-api} start";
      };

      environment = {
        TZDATA_DIR = "/var/lib/firezone/tzdata";
        TELEMETRY_ENABLED = "false";

        RELEASE_COOKIE = "agfea"; # TODO make option, if null generate automatically on first start
        RELEASE_NAME = "api";
        RELEASE_HOSTNAME = "localhost.localdomain";

        # Web Server
        WEB_EXTERNAL_URL = "http://localhost:8080/";
        API_EXTERNAL_URL = "http://localhost:8081/";

        HEALTHZ_PORT = "4002";

        # Debugging;
        LOG_LEVEL = "debug";

        # Erlang;
        ERLANG_DISTRIBUTION_PORT = "9000";
        ERLANG_CLUSTER_ADAPTER = "Elixir.Cluster.Strategy.Epmd";
        ERLANG_CLUSTER_ADAPTER_CONFIG = builtins.toJSON {
          hosts = [
            "api@localhost.localdomain"
            "web@localhost.localdomain"
            "domain@localhost.localdomain"
          ];
        };

        # Database;
        DATABASE_SOCKET_DIR = "/run/postgresql";
        DATABASE_PORT = "5432";
        DATABASE_NAME = "firezone";
        DATABASE_USER = "firezone";
        #DATABASE_HOST = "localhost";
        #DATABASE_PASSWORD = "";

        # Auth;
        AUTH_PROVIDER_ADAPTERS = "email,openid_connect,userpass,token,google_workspace,microsoft_entra,okta,jumpcloud";

        # Secrets;
        TOKENS_KEY_BASE = "5OVYJ83AcoQcPmdKNksuBhJFBhjHD1uUa9mDOHV/6EIdBQ6pXksIhkVeWIzFk5S2";
        SECRET_KEY_BASE = "5OVYJ83AcoQcPmdKNksuBhJFBhjHD1uUa9mDOHV/6EIdBQ6pXksIhkVeWIzFk5S2";
        TOKENS_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
        LIVE_VIEW_SIGNING_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
        COOKIE_SIGNING_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";
        COOKIE_ENCRYPTION_SALT = "t01wa0K4lUd7mKa0HAtZdE+jFOPDDej2";

        # Seeds;
        STATIC_SEEDS = "true";

        OUTBOUND_EMAIL_FROM = "public-noreply@firez.one";
        OUTBOUND_EMAIL_ADAPTER = "Elixir.Swoosh.Adapters.Postmark";
        ## Warning= The token is for the blackhole Postmark server created in a separate isolated account,;
        ## that WILL NOT send any actual emails, but you can see and debug them in the Postmark dashboard.;
        OUTBOUND_EMAIL_ADAPTER_OPTS = ''{"api_key":"7da7d1cd-111c-44a7-b5ac-4027b9d230e5"}'';

        # Feature flags;
        FEATURE_FLOW_ACTIVITIES_ENABLED = "true";
        FEATURE_POLICY_CONDITIONS_ENABLED = "true";
        FEATURE_MULTI_SITE_RESOURCES_ENABLED = "true";
        FEATURE_SELF_HOSTED_RELAYS_ENABLED = "true";
        FEATURE_IDP_SYNC_ENABLED = "true";
        FEATURE_REST_API_ENABLED = "true";
        FEATURE_INTERNET_RESOURCE_ENABLED = "true";
      };
    };
  };

  meta.maintainers = with lib.maintainers; [
    oddlama
    patrickdag
  ];
}
