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
    mkMerge
    mkOption
    mkPackageOption
    optional
    optionalAttrs
    types
    ;

  cfg = config.services.affine;
  dataDir = "/var/lib/affine";

  defaultUser = "affine";
  defaultGroup = "affine";

  settingsFormat = pkgs.formats.json { };

  # Shared by services.affine.ai.text and services.affine.ai.embedding.
  aiEndpointOptions = {
    baseUrl = mkOption {
      type = types.str;
      example = "http://127.0.0.1:8080";
      description = ''
        Base url of the OpenAI-compatible server. A trailing `/v1` is stripped before
        the api paths are appended, so both `http://host:8080` and `http://host:8080/v1`
        work.
      '';
    };

    apiKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/affine-openai-key";
      description = ''
        File containing the api key to authenticate with, if the server requires one.

        When unset a placeholder is sent instead of nothing, because AFFiNE treats a
        provider with an empty key as not configured and silently skips it.
      '';
    };
  };

  # AFFiNE wants an api key even for servers that do not check one.
  aiApiKey =
    endpoint: if endpoint.apiKeyFile != null then { _secret = endpoint.apiKeyFile; } else "local";

  aiProfile = id: endpoint: extraConfig: {
    inherit id;
    type = "openai";
    # Restrict each profile to the one model it serves, so AFFiNE never probes the
    # local server for models it does not have.
    models = [ endpoint.model ];
    config = {
      apiKey = aiApiKey endpoint;
      baseURL = endpoint.baseUrl;
    }
    // extraConfig;
  };
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

    ai = {
      enable = mkEnableOption ''
        AFFiNE AI (copilot) backed by OpenAI-compatible servers, for example llama.cpp
        or vLLM. See `services.affine.ai.text` for the model naming constraints
      '';

      text = mkOption {
        description = ''
          The server used for chat and structured output. Required when AI is enabled.
        '';
        type = types.submodule {
          options = aiEndpointOptions // {
            model = mkOption {
              type = types.enum [
                "o1"
                "o3"
                "o4-mini"
              ];
              default = "o3";
              description = ''
                Name your local model must be served under.

                AFFiNE resolves models against a registry that is compiled into its rust
                native module, so an unknown name simply has no provider and every request
                fails with `no_copilot_provider_available`. Only these three ids exist for
                the chat-completions API that llama.cpp and vLLM implement, so serve your
                model under one of them (llama-server --alias o3, or vLLM
                --served-model-name o3). Which one you pick makes no difference beyond the
                name, the actual model is whatever your server loaded.
              '';
            };
          };
        };
      };

      embedding = mkOption {
        default = null;
        description = ''
          The server used to embed documents, enabling AI search over the workspace.
          Set to null to leave embedding disabled.

          This is a separate option because AFFiNE only knows its embedding models under
          the openai responses api, while chat has to use the chat-completions api, and a
          single provider entry cannot be both. Pointing both at one server is fine.
        '';
        type = types.nullOr (
          types.submodule {
            options = aiEndpointOptions // {
              model = mkOption {
                type = types.enum [
                  "text-embedding-3-large"
                  "text-embedding-3-small"
                ];
                default = "text-embedding-3-large";
                description = ''
                  Name your local embedding model must be served under. As with
                  `services.affine.ai.text.model` only these registry ids resolve.
                  Embedding requests always go to `/v1/embeddings`.
                '';
              };
            };
          }
        );
      };
    };

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
      description = "";
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

    services.affine.settings = mkMerge [
      {
        auth.passwordRequirements.min = mkDefault 8;
        auth.passwordRequirements.max = mkDefault 1024; # Increase password-length limit from originally 32 to something more reasonable. Why limit this to something so small??
        flags.allowGuestDemoWorkspace = mkDefault false;

        # indexer = mkIf cfg.enableIndexer {
        #   enabled = true;
        #   "provider.type" = "manticoresearch";
        #   "provider.endpoint" = "http://localhost:9308";
        # };
      }
      (mkIf cfg.ai.enable {
        copilot = {
          enabled = true;
          providers = {
            profiles = [
              # llama.cpp and vLLM implement the chat-completions api, not the newer
              # responses api that AFFiNE would use for openai by default.
              (aiProfile "local-text" cfg.ai.text { oldApiStyle = true; })
            ]
            ++ optional (cfg.ai.embedding != null) (aiProfile "local-embedding" cfg.ai.embedding { });

            # These name profile ids, not models. AFFiNE refuses to start if one of
            # them refers to a profile that does not exist.
            #
            # `structured` and `image` are deliberately unset: the chat-completions
            # models only declare text and object output, so nothing would be able to
            # serve those requests anyway.
            defaults = {
              text = "local-text";
              object = "local-text";
              fallback = "local-text";
            }
            // optionalAttrs (cfg.ai.embedding != null) { embedding = "local-embedding"; };
          };
        };
      })
    ];

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
        if [[ ! -e .affine/config/private.key ]]; then
          mkdir -p .affine/config
          echo "Generating affine private key"
          ${lib.getExe pkgs.openssl} ecparam -name prime256v1 -genkey -noout -out .affine/config/private.key
        fi

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
