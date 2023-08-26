{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit
    (lib)
    all
    any
    attrNames
    attrValues
    concatLines
    concatLists
    concatMap
    concatMapStrings
    converge
    elem
    escapeShellArg
    escapeShellArgs
    filter
    filterAttrsRecursive
    flip
    foldl'
    getExe
    hasInfix
    hasPrefix
    isStorePath
    mapAttrs
    mapAttrsToList
    mdDoc
    mkEnableOption
    mkForce
    mkIf
    mkMerge
    mkOption
    mkPackageOptionMD
    optional
    optionals
    subtractLists
    types
    ;

  cfg = config.services.kanidm;
  settingsFormat = pkgs.formats.toml {};
  # Remove null values, so we can document optional values that don't end up in the generated TOML file.
  filterConfig = converge (filterAttrsRecursive (_: v: v != null));
  serverConfigFile = settingsFormat.generate "server.toml" (filterConfig cfg.serverSettings);
  clientConfigFile = settingsFormat.generate "kanidm-config.toml" (filterConfig cfg.clientSettings);
  unixConfigFile = settingsFormat.generate "kanidm-unixd.toml" (filterConfig cfg.unixSettings);
  certPaths = builtins.map builtins.dirOf [cfg.serverSettings.tls_chain cfg.serverSettings.tls_key];

  # Merge bind mount paths and remove paths where a prefix is already mounted.
  # This makes sure that if e.g. the tls_chain is in the nix store and /nix/store is already in the mount
  # paths, no new bind mount is added. Adding subpaths caused problems on ofborg.
  hasPrefixInList = list: newPath: any (path: hasPrefix (builtins.toString path) (builtins.toString newPath)) list;
  mergePaths = foldl' (merged: newPath: let
    # If the new path is a prefix to some existing path, we need to filter it out
    filteredPaths = filter (p: !hasPrefix (builtins.toString newPath) (builtins.toString p)) merged;
    # If a prefix of the new path is already in the list, do not add it
    filteredNew = optional (!hasPrefixInList filteredPaths newPath) newPath;
  in
    filteredPaths ++ filteredNew) [];

  defaultServiceConfig = {
    BindReadOnlyPaths = [
      "/nix/store"
      "-/etc/resolv.conf"
      "-/etc/nsswitch.conf"
      "-/etc/hosts"
      "-/etc/localtime"
    ];
    CapabilityBoundingSet = [];
    # ProtectClock= adds DeviceAllow=char-rtc r
    DeviceAllow = "";
    # Implies ProtectSystem=strict, which re-mounts all paths
    # DynamicUser = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateMounts = true;
    PrivateNetwork = true;
    PrivateTmp = true;
    PrivateUsers = true;
    ProcSubset = "pid";
    ProtectClock = true;
    ProtectHome = true;
    ProtectHostname = true;
    # Would re-mount paths ignored by temporary root
    #ProtectSystem = "strict";
    ProtectControlGroups = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    RestrictAddressFamilies = [];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = ["@system-service" "~@privileged @resources @setuid @keyring"];
    # Does not work well with the temporary root
    #UMask = "0066";
  };

  mkPresentOption = what:
    mkOption {
      description = mdDoc "Whether to ensure that this ${what} is present or absent.";
      type = types.bool;
      default = true;
    };

  mkScript = script:
    mkOption {
      readOnly = true;
      internal = true;
      type = types.str;
      default = script;
    };

  mappingsJson = pkgs.writeText "mappings.json" (builtins.toJSON {
    account_credentials.admin = cfg.provision.adminPasswordFile;
    account_credentials.idm_admin = cfg.provision.idmAdminPasswordFile;
    oauth2_basic_secrets = mapAttrs (_: x: x.basicSecretFile) cfg.provision.systems.oauth2;
  });

  preStartScript = pkgs.writeShellScript "pre-start-manipulate" ''
    if ! test -e ${escapeShellArg cfg.serverSettings.db_path}; then
      touch "$STATE_DIRECTORY/.first_startup"
    else
      ${getExe pkgs.kanidm-secret-manipulator} ${escapeShellArg cfg.serverSettings.db_path} ${mappingsJson}
    fi
  '';

  restarterScript = pkgs.writeShellScript "post-start-restarter" ''
    set -euo pipefail
    if test -e "$STATE_DIRECTORY/.needs_restart"; then
      rm -f "$STATE_DIRECTORY/.needs_restart"
      echo "Restarting kanidm.service..."
      #kill -TERM $MAINPID
      #echo "Restarting kanidm.service via dbus..."
      ${pkgs.dbus}/bin/dbus-send --system --type=method_call --print-reply --dest=org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager.RestartUnit string:"kanidm.service" string:"replace"
    fi
  '';

  postStartScript = pkgs.writeShellScript "post-start" ''
    set -euo pipefail

    # Wait for the kanidm server to come online
    count=0
    while ! test -e /run/kanidmd/sock; do
      if [ "$count" -eq 600 ]; then
        echo "Tried for 60 seconds, giving up..."
        exit 1
      fi
      if ! kill -0 "$MAINPID"; then
        echo "Main server died, giving up..."
        exit 1
      fi
      sleep 0.1
      count=$((count++))
    done

    # If this is the first start, we login this time by recovering the admin account
    # and force a restart afterwards to rewrite the password.
    if test -e "$STATE_DIRECTORY/.first_startup"; then
      # Recover admin account
      if ! recover_out=$(${cfg.package}/bin/kanidmd recover-account -c ${serverConfigFile} admin); then
        echo "$recover_out" >&2
        echo "kanidm provision: Failed to recover admin account" >&2
        exit 1
      fi
      if ! KANIDM_PASSWORD_ADMIN=$(grep -o '[A-Za-z0-9]\{48\}' <<< "$recover_out"); then
        echo "$recover_out" >&2
        echo "kanidm provision: Failed to parse password for admin account" >&2
        exit 1
      fi

      # Recover idm_admin account
      if ! recover_out=$(${cfg.package}/bin/kanidmd recover-account -c ${serverConfigFile} idm_admin); then
        echo "$recover_out" >&2
        echo "kanidm provision: Failed to recover admin account" >&2
        exit 1
      fi
      if ! KANIDM_PASSWORD_IDM=$(grep -o '[A-Za-z0-9]\{48\}' <<< "$recover_out"); then
        echo "$recover_out" >&2
        echo "kanidm provision: Failed to parse password for idm_admin account" >&2
        exit 1
      fi
      needs_rewrite=1
      rm -f "$STATE_DIRECTORY/.first_startup"
    else
      # Login using the admin password
      KANIDM_PASSWORD_ADMIN="$(< ${escapeShellArg cfg.provision.adminPasswordFile})"
      KANIDM_PASSWORD_IDM="$(< ${escapeShellArg cfg.provision.idmAdminPasswordFile})"
    fi

    # Login to admin and idm_admin
    export TMPDIR=$(mktemp -d)
    trap 'rm -rf $TMPDIR' EXIT
    # Set $HOME so kanidm can save the token temporarily
    export HOME=$TMPDIR
    KANIDM_PASSWORD=$KANIDM_PASSWORD_ADMIN ${cfg.package}/bin/kanidm login --name admin \
      || { echo "kanidm provision: Failed to login as admin, see kanidm logs." >&2; exit 1; }
    KANIDM_PASSWORD=$KANIDM_PASSWORD_IDM ${cfg.package}/bin/kanidm login --name idm_admin \
      || { echo "kanidm provision: Failed to login as idm_admin, see kanidm logs." >&2; exit 1; }

    # Wrapper function that detects kanidm errors by detecting any output to stderr
    # (stderr and stdout are swapped when calling this)
    function kanidm-detect-err() {
      if ! err=$(${cfg.package}/bin/kanidm "$@" 3>&2 2>&1 1>&3-); then
        echo "$err"
        echo "kanidm ''${*@Q}: failed with status $?, see error above"
        exit 1
      fi
      if [[ -n "$err" ]]; then
        echo "$err"
        echo "kanidm ''${*@Q}: failed, see error above"
        exit 1
      fi
    }

    # Wrapper function to easily execute commands as admin or idm_admin
    function kanidm-as-user() {
      name=$1
      shift
      kanidm-detect-err "$@" --name "$name" 3>&2 2>&1 1>&3-
    }

    function kanidm-admin() { kanidm-as-user admin "$@"; }
    function kanidm-idm() { kanidm-as-user idm_admin "$@"; }

    known_groups=$(kanidm-admin group list --output=json)
    function group_exists() {
      if ! x=$(${getExe pkgs.jq} <<< "$known_groups" ".[] | select(.name[0] == \"$1\")"); then
        echo "kanidm provision: Failed to parse groups list." >&2
        exit 1
      fi
      [[ -n "$x" ]]
    }

    known_persons=$(kanidm-admin person list --output=json)
    function person_exists() {
      if ! x=$(${getExe pkgs.jq} <<< "$known_persons" ".[] | select(.name[0] == \"$1\")"); then
        echo "kanidm provision: Failed to parse persons list." >&2
        exit 1
      fi
      [[ -n "$x" ]]
    }

    known_oauth2_systems=$(kanidm-admin system oauth2 list --output=json)
    function oauth2_system_exists() {
      if ! x=$(${getExe pkgs.jq} <<< "$known_oauth2_systems" ".[] | select(.oauth2_rs_name[0] == \"$1\")"); then
        echo "kanidm provision: Failed to parse oauth2 systems list." >&2
        exit 1
      fi
      [[ -n "$x" ]]
    }

    ${concatMapStrings (x: x._script) (attrValues cfg.provision.groups)}
    ${concatMapStrings (x: x._script) (attrValues cfg.provision.persons)}
    ${concatMapStrings (x: x._script) (attrValues cfg.provision.systems.oauth2)}

    if [[ "''${needs_rewrite-0}" == 1 ]]; then
      echo "Queueing service restart to rewrite secrets"
      touch "$STATE_DIRECTORY/.needs_restart"
    fi
  '';
in {
  options.services.kanidm = {
    enableClient = mkEnableOption (mdDoc "the Kanidm client");
    enableServer = mkEnableOption (mdDoc "the Kanidm server");
    enablePam = mkEnableOption (mdDoc "the Kanidm PAM and NSS integration");

    package = mkPackageOptionMD pkgs "kanidm" {};

    provision = {
      enable = mkEnableOption "provisioning of systems (oauth2), groups and users";

      adminPasswordFile = mkOption {
        description = mdDoc "Path to a file containing the admin password for kanidm. Do NOT use a file from the nix store here!";
        example = "/run/secrets/kanidm-admin-password";
        type = types.path;
      };

      idmAdminPasswordFile = mkOption {
        description = mdDoc "Path to a file containing the idm admin password for kanidm. Do NOT use a file from the nix store here!";
        example = "/run/secrets/kanidm-idm-admin-password";
        type = types.path;
      };

      persons = mkOption {
        description = mdDoc "Provisioning of kanidm persons";
        default = {};
        type = types.attrsOf (types.submodule (personSubmod: let
          inherit (personSubmod.config._module.args) name;
          updateArgs =
            ["--displayname" personSubmod.config.displayName]
            ++ optionals (personSubmod.config.legalName != null)
            ["--legalname" personSubmod.config.legalName]
            # mail addresses
            ++ concatMap (addr: ["--mail" addr]) personSubmod.config.mailAddresses;
        in {
          options = {
            _script = mkScript (
              if personSubmod.config.present
              then
                ''
                  if ! person_exists ${escapeShellArg name}; then
                    kanidm-idm person create ${escapeShellArg name} \
                      ${escapeShellArg personSubmod.config.displayName}
                  fi
                  kanidm-idm person update ${escapeShellArg name} ${escapeShellArgs updateArgs}
                ''
                + flip concatMapStrings personSubmod.config.groups (group: ''
                  kanidm-idm group add-members ${escapeShellArg group} ${escapeShellArg name}
                '')
              else ''
                if person_exists ${escapeShellArg name}; then
                  kanidm-idm person delete ${escapeShellArg name}
                fi
              ''
            );

            present = mkPresentOption "person";

            displayName = mkOption {
              description = mdDoc "Display name";
              type = types.str;
              example = "My User";
            };

            legalName = mkOption {
              description = mdDoc "Full legal name";
              type = types.nullOr types.str;
              example = "Jane Doe";
              default = null;
            };

            mailAddresses = mkOption {
              description = mdDoc "Mail addresses. First given address is considered the primary address.";
              type = types.listOf types.str;
              example = ["jane.doe@example.com"];
              default = [];
            };

            groups = mkOption {
              description = mdDoc "List of kanidm groups to which this user belongs.";
              type = types.listOf types.str;
              default = [];
            };
          };
        }));
      };

      groups = mkOption {
        description = mdDoc "Provisioning of kanidm groups";
        default = {};
        type = types.attrsOf (types.submodule (groupSubmod: let
          inherit (groupSubmod.config._module.args) name;
        in {
          options = {
            _script = mkScript (
              if groupSubmod.config.present
              then ''
                if ! group_exists ${escapeShellArg name}; then
                  kanidm-admin group create ${escapeShellArg name}
                fi
              ''
              else ''
                if group_exists ${escapeShellArg name}; then
                  kanidm-admin group delete ${escapeShellArg name}
                fi
              ''
            );

            present = mkPresentOption "group";
          };
        }));
      };

      systems.oauth2 = mkOption {
        description = mdDoc "Provisioning of oauth2 systems";
        default = {};
        type = types.attrsOf (types.submodule (oauth2Submod: let
          inherit (oauth2Submod.config._module.args) name;
        in {
          options = {
            _script = mkScript (
              if oauth2Submod.config.present
              then
                ''
                  if ! oauth2_system_exists ${escapeShellArg name}; then
                    kanidm-admin system oauth2 create \
                      ${escapeShellArg name} \
                      ${escapeShellArg oauth2Submod.config.displayName} \
                      ${escapeShellArg oauth2Submod.config.originUrl}
                    needs_rewrite=1
                  fi
                ''
                + concatLines (flip mapAttrsToList oauth2Submod.config.scopeMaps (group: scopes: ''
                  kanidm-admin system oauth2 update-scope-map ${escapeShellArg name} \
                    ${escapeShellArg group} ${escapeShellArgs scopes}
                ''))
                + concatLines (flip mapAttrsToList oauth2Submod.config.supplementaryScopeMaps (group: scopes: ''
                  kanidm-admin system oauth2 update-sup-scope-map ${escapeShellArg name} \
                    ${escapeShellArg group} ${escapeShellArgs scopes}
                ''))
              else ''
                if oauth2_system_exists ${escapeShellArg name}; then
                  kanidm-admin system oauth2 delete ${escapeShellArg name}
                fi
              ''
            );

            present = mkPresentOption "oauth2 system";

            displayName = mkOption {
              description = mdDoc "Display name";
              type = types.str;
              example = "Some Service";
            };

            originUrl = mkOption {
              description = mdDoc "The basic secret to use for this service. If null, the random secret generated by kanidm will not be touched. Do NOT use a path from the nix store here!";
              type = types.str;
              example = "https://someservice.example.com/";
            };

            basicSecretFile = mkOption {
              description = mdDoc "The basic secret to use for this service. If null, the random secret generated by kanidm will not be touched. Do NOT use a path from the nix store here!";
              type = types.nullOr types.path;
              example = "/run/secrets/some-oauth2-basic-secret";
              default = null;
            };

            scopeMaps = mkOption {
              description = mdDoc "Maps kanidm groups to provided scopes. See [Scope Relations](https://kanidm.github.io/kanidm/stable/integrations/oauth2.html#scope-relationships) for more information.";
              type = types.attrsOf (types.listOf types.str);
              default = {};
            };

            supplementaryScopeMaps = mkOption {
              description = mdDoc "Maps kanidm groups to provided supplementary scopes. See [Scope Relations](https://kanidm.github.io/kanidm/stable/integrations/oauth2.html#scope-relationships) for more information.";
              type = types.attrsOf (types.listOf types.str);
              default = {};
            };
          };
        }));
      };
    };

    serverSettings = mkOption {
      type = types.submodule {
        freeformType = settingsFormat.type;

        options = {
          bindaddress = mkOption {
            description = mdDoc "Address/port combination the webserver binds to.";
            example = "[::1]:8443";
            type = types.str;
          };
          # Should be optional but toml does not accept null
          ldapbindaddress = mkOption {
            description = mdDoc ''
              Address and port the LDAP server is bound to. Setting this to `null` disables the LDAP interface.
            '';
            example = "[::1]:636";
            default = null;
            type = types.nullOr types.str;
          };
          origin = mkOption {
            description = mdDoc "The origin of your Kanidm instance. Must have https as protocol.";
            example = "https://idm.example.org";
            type = types.strMatching "^https://.*";
          };
          domain = mkOption {
            description = mdDoc ''
              The `domain` that Kanidm manages. Must be below or equal to the domain
              specified in `serverSettings.origin`.
              This can be left at `null`, only if your instance has the role `ReadOnlyReplica`.
              While it is possible to change the domain later on, it requires extra steps!
              Please consider the warnings and execute the steps described
              [in the documentation](https://kanidm.github.io/kanidm/stable/administrivia.html#rename-the-domain).
            '';
            example = "example.org";
            default = null;
            type = types.nullOr types.str;
          };
          db_path = mkOption {
            description = mdDoc "Path to Kanidm database.";
            default = "/var/lib/kanidm/kanidm.db";
            readOnly = true;
            type = types.path;
          };
          tls_chain = mkOption {
            description = mdDoc "TLS chain in pem format.";
            type = types.path;
          };
          tls_key = mkOption {
            description = mdDoc "TLS key in pem format.";
            type = types.path;
          };
          log_level = mkOption {
            description = mdDoc "Log level of the server.";
            default = "info";
            type = types.enum ["info" "debug" "trace"];
          };
          role = mkOption {
            description = mdDoc "The role of this server. This affects the replication relationship and thereby available features.";
            default = "WriteReplica";
            type = types.enum ["WriteReplica" "WriteReplicaNoUI" "ReadOnlyReplica"];
          };
        };
      };
      default = {};
      description = mdDoc ''
        Settings for Kanidm, see
        [the documentation](https://github.com/kanidm/kanidm/blob/master/kanidm_book/src/server_configuration.md)
        and [example configuration](https://github.com/kanidm/kanidm/blob/master/examples/server.toml)
        for possible values.
      '';
    };

    clientSettings = mkOption {
      type = types.submodule {
        freeformType = settingsFormat.type;

        options.uri = mkOption {
          description = mdDoc "Address of the Kanidm server.";
          example = "http://127.0.0.1:8080";
          type = types.str;
        };
      };
      description = mdDoc ''
        Configure Kanidm clients, needed for the PAM daemon. See
        [the documentation](https://github.com/kanidm/kanidm/blob/master/kanidm_book/src/client_tools.md#kanidm-configuration)
        and [example configuration](https://github.com/kanidm/kanidm/blob/master/examples/config)
        for possible values.
      '';
    };

    unixSettings = mkOption {
      type = types.submodule {
        freeformType = settingsFormat.type;

        options.pam_allowed_login_groups = mkOption {
          description = mdDoc "Kanidm groups that are allowed to login using PAM.";
          example = "my_pam_group";
          type = types.listOf types.str;
        };
      };
      description = mdDoc ''
        Configure Kanidm unix daemon.
        See [the documentation](https://github.com/kanidm/kanidm/blob/master/kanidm_book/src/pam_and_nsswitch.md#the-unix-daemon)
        and [example configuration](https://github.com/kanidm/kanidm/blob/master/examples/unixd)
        for possible values.
      '';
    };
  };

  config = mkIf (cfg.enableClient || cfg.enableServer || cfg.enablePam) {
    assertions =
      [
        {
          assertion = !cfg.enableServer || ((cfg.serverSettings.tls_chain or null) == null) || (!isStorePath cfg.serverSettings.tls_chain);
          message = ''
            <option>services.kanidm.serverSettings.tls_chain</option> points to
            a file in the Nix store. You should use a quoted absolute path to
            prevent this.
          '';
        }
        {
          assertion = !cfg.enableServer || ((cfg.serverSettings.tls_key or null) == null) || (!isStorePath cfg.serverSettings.tls_key);
          message = ''
            <option>services.kanidm.serverSettings.tls_key</option> points to
            a file in the Nix store. You should use a quoted absolute path to
            prevent this.
          '';
        }
        {
          assertion = !cfg.enableClient || options.services.kanidm.clientSettings.isDefined;
          message = ''
            <option>services.kanidm.clientSettings</option> needs to be configured
            if the client is enabled.
          '';
        }
        {
          assertion = !cfg.enablePam || options.services.kanidm.clientSettings.isDefined;
          message = ''
            <option>services.kanidm.clientSettings</option> needs to be configured
            for the PAM daemon to connect to the Kanidm server.
          '';
        }
        {
          assertion =
            !cfg.enableServer
            || (cfg.serverSettings.domain
              == null
              -> cfg.serverSettings.role == "WriteReplica" || cfg.serverSettings.role == "WriteReplicaNoUI");
          message = ''
            <option>services.kanidm.serverSettings.domain</option> can only be set if this instance
            is not a ReadOnlyReplica. Otherwise the db would inherit it from
            the instance it follows.
          '';
        }
        {
          assertion = cfg.provision.enable -> cfg.enableServer;
          message = "<option>services.kanidm.provision</option> requires <option>services.kanidm.enableServer</option> to be true";
        }
        {
          assertion = cfg.provision.enable -> cfg.enableClient;
          message = "<option>services.kanidm.provision</option> requires <option>services.kanidm.enableClient</option> to be able to use the kanidm client locally for provisioning.";
        }
      ]
      ++ flip mapAttrsToList cfg.provision.persons (person: personCfg: let
        unknownGroups = subtractLists (attrNames cfg.provision.groups) personCfg.groups;
      in {
        assertion = (cfg.enableServer && cfg.provision.enable) -> unknownGroups == [];
        message = "kanidm: provision.persons.${person}.groups: Refers to unknown groups: ${unknownGroups}";
      })
      ++ concatLists (flip mapAttrsToList cfg.provision.systems.oauth2 (oauth2: oauth2Cfg: [
        {
          assertion = (cfg.enableServer && cfg.provision.enable) -> hasInfix "://" oauth2Cfg.originUrl;
          message = "kanidm: provision.systems.oauth2.${oauth2}.originUrl: Missing a schema like 'https://': ${oauth2Cfg.originUrl}";
        }
        (let
          unknownGroups = subtractLists (attrNames cfg.provision.groups) (attrNames oauth2Cfg.scopeMaps);
        in {
          assertion = (cfg.enableServer && cfg.provision.enable) -> unknownGroups == [];
          message = "kanidm: provision.systems.oauth2.${oauth2}.scopeMaps: Refers to unknown groups: ${unknownGroups}";
        })
        (let
          unknownGroups = subtractLists (attrNames cfg.provision.groups) (attrNames oauth2Cfg.supplementaryScopeMaps);
        in {
          assertion = (cfg.enableServer && cfg.provision.enable) -> unknownGroups == [];
          message = "kanidm: provision.systems.oauth2.${oauth2}.supplementaryScopeMaps: Refers to unknown groups: ${unknownGroups}";
        })
      ]));

    environment.systemPackages = mkIf cfg.enableClient [cfg.package];

    systemd.services.kanidm = mkIf cfg.enableServer {
      description = "kanidm identity management daemon";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = mkMerge [
        # Merge paths and ignore existing prefixes needs to sidestep mkMerge
        (defaultServiceConfig
          // {
            BindReadOnlyPaths = mergePaths (
              defaultServiceConfig.BindReadOnlyPaths
              ++ certPaths
              # If provisioning is enabled, we need access to the client config to use the kanidm cli,
              # and to the installed system certificates.
              ++ optionals cfg.provision.enable [
                "-/etc/ssl/certs"
                "-/etc/static/ssl/certs"
                "-/etc/kanidm"
                "-/etc/static/kanidm"
              ]
            );
          })
        {
          StateDirectory = "kanidm";
          StateDirectoryMode = "0700";
          RuntimeDirectory = "kanidmd";
          ExecStartPre = mkIf cfg.provision.enable [preStartScript];
          ExecStart = "${cfg.package}/bin/kanidmd server -c ${serverConfigFile}";
          ExecStartPost =
            mkIf cfg.provision.enable
            [
              postStartScript
              # Only the restarter runs with elevated privileges
              "+${restarterScript}"
            ];
          User = "kanidm";
          Group = "kanidm";

          BindPaths = [
            # To create the socket
            "/run/kanidmd:/run/kanidmd"
            "/run/dbus/system_bus_socket"
          ];

          AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
          CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];
          # This would otherwise override the CAP_NET_BIND_SERVICE capability.
          PrivateUsers = mkForce false;
          # Port needs to be exposed to the host network
          PrivateNetwork = mkForce false;
          RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
          TemporaryFileSystem = "/:ro";
        }
      ];
      environment.RUST_LOG = "info";
    };

    systemd.services.kanidm-unixd = mkIf cfg.enablePam {
      description = "Kanidm PAM daemon";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      restartTriggers = [unixConfigFile clientConfigFile];
      serviceConfig = mkMerge [
        defaultServiceConfig
        {
          CacheDirectory = "kanidm-unixd";
          CacheDirectoryMode = "0700";
          RuntimeDirectory = "kanidm-unixd";
          ExecStart = "${cfg.package}/bin/kanidm_unixd";
          User = "kanidm-unixd";
          Group = "kanidm-unixd";

          BindReadOnlyPaths = [
            "-/etc/kanidm"
            "-/etc/static/kanidm"
            "-/etc/ssl"
            "-/etc/static/ssl"
            "-/etc/passwd"
            "-/etc/group"
          ];
          BindPaths = [
            # To create the socket
            "/run/kanidm-unixd:/var/run/kanidm-unixd"
          ];
          # Needs to connect to kanidmd
          PrivateNetwork = mkForce false;
          RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
          TemporaryFileSystem = "/:ro";
        }
      ];
      environment.RUST_LOG = "info";
    };

    systemd.services.kanidm-unixd-tasks = mkIf cfg.enablePam {
      description = "Kanidm PAM home management daemon";
      wantedBy = ["multi-user.target"];
      after = ["network.target" "kanidm-unixd.service"];
      partOf = ["kanidm-unixd.service"];
      restartTriggers = [unixConfigFile clientConfigFile];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/kanidm_unixd_tasks";

        BindReadOnlyPaths = [
          "/nix/store"
          "-/etc/resolv.conf"
          "-/etc/nsswitch.conf"
          "-/etc/hosts"
          "-/etc/localtime"
          "-/etc/kanidm"
          "-/etc/static/kanidm"
        ];
        BindPaths = [
          # To manage home directories
          "/home"
          # To connect to kanidm-unixd
          "/run/kanidm-unixd:/var/run/kanidm-unixd"
        ];
        # CAP_DAC_OVERRIDE is needed to ignore ownership of unixd socket
        CapabilityBoundingSet = ["CAP_CHOWN" "CAP_FOWNER" "CAP_DAC_OVERRIDE" "CAP_DAC_READ_SEARCH"];
        IPAddressDeny = "any";
        # Need access to users
        PrivateUsers = false;
        # Need access to home directories
        ProtectHome = false;
        RestrictAddressFamilies = ["AF_UNIX"];
        TemporaryFileSystem = "/:ro";
        Restart = "on-failure";
      };
      environment.RUST_LOG = "info";
    };

    # These paths are hardcoded
    environment.etc = mkMerge [
      (mkIf cfg.enableServer {
        "kanidm/server.toml".source = serverConfigFile;
      })
      (mkIf options.services.kanidm.clientSettings.isDefined {
        "kanidm/config".source = clientConfigFile;
      })
      (mkIf cfg.enablePam {
        "kanidm/unixd".source = unixConfigFile;
      })
    ];

    system.nssModules = mkIf cfg.enablePam [cfg.package];

    system.nssDatabases.group = optional cfg.enablePam "kanidm";
    system.nssDatabases.passwd = optional cfg.enablePam "kanidm";

    users.groups = mkMerge [
      (mkIf cfg.enableServer {
        kanidm = {};
      })
      (mkIf cfg.enablePam {
        kanidm-unixd = {};
      })
    ];
    users.users = mkMerge [
      (mkIf cfg.enableServer {
        kanidm = {
          description = "Kanidm server";
          isSystemUser = true;
          group = "kanidm";
          packages = [cfg.package];
        };
      })
      (mkIf cfg.enablePam {
        kanidm-unixd = {
          description = "Kanidm PAM daemon";
          isSystemUser = true;
          group = "kanidm-unixd";
        };
      })
    ];
  };

  meta.maintainers = with lib.maintainers; [erictapen Flakebi oddlama];
  meta.buildDocsInSandbox = false;
}
