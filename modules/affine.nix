{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  inherit (lib)
    getExe
    hasPrefix
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    optional
    types
    ;

  cfg = config.services.affine;
  dataDir = "/var/lib/affine";

  defaultUser = "affine";
  defaultGroup = "affine";

  settingsFormat = pkgs.formats.json { };
in
{
  options.services.affine = {
    enable = mkEnableOption "AFFiNE server.";
    package = mkPackageOption pkgs "affine-server" { };

    user = mkOption {
      type = types.str;
      default = defaultUser;
      description = "User under which affine runs. If you set this option you must make sure the user exists.";
    };

    group = mkOption {
      type = types.str;
      default = defaultGroup;
      description = "Group under which affine runs. If you set this option you must make sure the group exists.";
    };

    enableLocalDB = mkEnableOption "the automatic creation of a local postgres database for affine.";
    # enableIndexer = mkEnableOption "server-side indexing by setting up services.manticoresearch locally.";

    database = {
      host = mkOption {
        type = types.str;
        description = "The database host";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "The database port";
      };

      name = mkOption {
        type = types.str;
        description = "The database name";
      };

      user = mkOption {
        type = types.str;
        description = "The database user";
      };

      # TODO: passwordFile
    };

    settings = mkOption {
      description = '''';
      default = { };
      type = types.submodule {
        freeformType = settingsFormat.type;
        options = {
          server = {
            name = mkOption {
              type = types.str;
              description = "A recognizable name for the server. Will be shown when connected with AFFiNE Desktop.";
            };

            externalUrl = mkOption {
              type = types.str;
              description = "Base url of AFFiNE server, used for generating external urls.";
            };

            host = mkOption {
              type = types.str;
              default = "localhost";
              description = "Address to listen on (FQDN or IP).";
            };

            port = mkOption {
              type = types.port;
              default = 3010;
              description = "Port to listen on.";
            };
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    services.redis.servers.affine = {
      enable = true;
      port = 6379;
    };

    services.postgresql = mkIf cfg.enableLocalDB {
      enable = true;
      ensureDatabases = [ "affine" ];
      ensureUsers = [
        {
          name = "affine";
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
      extensions = ps: [ ps.pgvector ];
      settings = {
        search_path = "\"$user\", public, vectors";
      };
    };

    # services.manticore.enable = mkIf cfg.enableIndexer true;

    systemd.services.postgresql-setup.serviceConfig.ExecStartPost =
      let
        extensions = [
          "vector"
        ];
        sqlFile = pkgs.writeText "affine-pgvector-setup.sql" ''
          ${lib.concatMapStringsSep "\n" (ext: "CREATE EXTENSION IF NOT EXISTS \"${ext}\";") extensions}

          ALTER SCHEMA public OWNER TO ${cfg.database.user};
          GRANT SELECT ON TABLE pg_vector_index_stat TO ${cfg.database.user};

          ${lib.concatMapStringsSep "\n" (ext: "ALTER EXTENSION \"${ext}\" UPDATE;") extensions}
        '';
      in
      [
        ''
          ${lib.getExe' config.services.postgresql.package "psql"} -d "${cfg.database.name}" -f "${sqlFile}"
        ''
      ];

    services.affine.database = mkIf cfg.enableLocalDB {
      host = "/run/postgresql";
      port = 5432;
      name = "affine";
      user = "affine";
    };

    services.affine.settings = {
      auth.passwordRequirements.min = mkDefault 8;
      auth.passwordRequirements.max = mkDefault 1024; # Increase password-length limit from originally 32 to something more reasonable. Why limit this to something so small??
      flags.allowGuestDemoWorkspace = mkDefault false;

      # indexer = mkIf cfg.enableIndexer {
      #   enabled = true;
      #   "provider.type" = "manticoresearch";
      #   "provider.endpoint" = "http://localhost:9308";
      # };
    };

    users = {
      users = mkIf (cfg.user == defaultUser) {
        ${defaultUser} = {
          description = "affine service user";
          inherit (cfg) group;
          isSystemUser = true;
          home = dataDir;
        };
      };
      groups = mkIf (cfg.group == defaultGroup) { ${defaultGroup} = { }; };
    };

    systemd.services.affine = {
      description = "AFFiNE server";
      after = [
        "network.target"
      ]
      #++ optional cfg.enableIndexer "manticore.service"
      ++ optional cfg.enableLocalDB "postgresql.service";
      requires =
        # optional cfg.enableIndexer "manticore.service" ++
        optional cfg.enableLocalDB "postgresql.service";
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        # Generate config including secret values.
        ${utils.genJqSecretsReplacementSnippet cfg.settings "/run/affine/config.json"}
        mkdir -p ${dataDir}/.affine/config
        ln -sTf /run/affine/config.json ${dataDir}/.affine/config/config.json
      '';

      serviceConfig = {
        ExecStart = getExe cfg.package;
        Type = "simple";
        Restart = "on-failure";

        AmbientCapablities = [ ];
        CapabilityBoundingSet = [ ];
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateMounts = true;
        PrivateTmp = true;
        PrivateUsers = false;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = "@system-service";
        UMask = "077";

        User = cfg.user;
        Group = cfg.group;

        BindReadOnlyPaths = [
          "${cfg.package}/schema.prisma:${dataDir}/schema.prisma"
          "${cfg.package}/migrations:${dataDir}/migrations"
        ];

        SyslogIdentifier = "affine";
        StateDirectory = "affine";
        RuntimeDirectory = "affine";
        WorkingDirectory = dataDir;
      };

      environment = {
        LD_PRELOAD = "${pkgs.jemalloc}/lib/libjemalloc.so";

        REDIS_SERVER_HOST = "localhost";
        REDIS_SERVER_PORT = toString config.services.redis.servers.affine.port;
        DATABASE_URL =
          if hasPrefix "/" cfg.database.host then
            "postgresql://${cfg.database.user}@localhost/${cfg.database.name}?host=${cfg.database.host}"
          else
            "postgresql://${cfg.database.user}@${cfg.database.host}:${cfg.database.port}/${cfg.database.name}";

        AFFINE_REVISION = "stable";
      };
    };

    meta.maintainers = with lib.maintainers; [ oddlama ];
  };
}
