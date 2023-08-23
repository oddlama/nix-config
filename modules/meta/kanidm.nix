{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    all
    attrNames
    attrValues
    concatLines
    concatLists
    concatMap
    concatMapStrings
    elem
    escapeShellArg
    flip
    mapAttrsToList
    mkOption
    optionals
    subtractLists
    types
    ;

  cfg = config.services.kanidm;

  mkPresentOption = what:
    mkOption {
      description = "Whether to ensure that this ${what} is present or absent.";
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

  provisionScript = pkgs.writeShellScript "post-start-provision" ''
    set -euo pipefail

    # Wait for the kanidm server to come online
    count=0
    while ! test -e /run/kanidmd/sock; do
      if [ "$count" -eq 300 ]; then
        echo "Tried for 30 seconds, giving up..."
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
      KANIDM_PASSWORD="$(${cfg.package}/bin/kanidmd recover-account admin)"
      needs_rewrite=1
      rm -f "$STATE_DIRECTORY/.first_startup"
    else
      # Login using the admin password
      KANIDM_PASSWORD="$(< ${escapeShellArg cfg.provision.adminPasswordFile})"
    fi

    ${cfg.package}/bin/kanidm login --name admin <<< "$KANIDM_PASSWORD"

    known_groups=$(kanidm group list --output=json)
    function group_exists() {
      [[ -n "$(${getExe jq} <<< "$known_groups" '. | select(.name[0] == "$1")')" ]]
    }

    known_persons=$(kanidm person list --output=json)
    function person_exists() {
      [[ -n "$(${getExe jq} <<< "$known_persons" '. | select(.name[0] == "$1")')" ]]
    }

    known_oauth2_systems=$(kanidm person list --output=json)
    function oauth2_system_exists() {
      [[ -n "$(${getExe jq} <<< "$known_oauth2_systems" '. | select(.oauth2_rs_name[0] == "$1")')" ]]
    }

    ${concatMapStrings (x: x._script) (attrValues cfg.provision.groups)}
    ${concatMapStrings (x: x._script) (attrValues cfg.provision.persons)}
    ${concatMapStrings (x: x._script) (attrValues cfg.provision.systems.oauth2)}

    if [[ "''${needs_rewrite-0}" == 1 ]]; then
      echo "Queueing service restart to rewrite secrets"
      touch "$STATE_DIRECTORY/.needs_restart"
    fi
  '';

  restarterScript = pkgs.writeShellScript "post-start-restarter" ''
    set -euo pipefail
    if test -e "$STATE_DIRECTORY/.needs_restart"; then
      rm -f "$STATE_DIRECTORY/.needs_restart"
      /run/current-system/systemd/bin/systemctl restart kanidm
    fi
  '';
in {
  options.services.kanidm.provision = {
    enable = mkEnableOption "provisioning of systems (oauth2), groups and users";

    adminPasswordFile = mkOption {
      description = "Path to a file containing the admin password for kanidm. Do NOT use a file from the nix store here!";
      example = "/run/secrets/kanidm-admin-password";
      type = types.path;
    };

    persons = mkOption {
      description = "Provisioning of kanidm persons";
      default = {};
      type = types.attrsOf (types.submodule (personSubmod: let
        inherit (personSubmod.module._args) name;
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
                  kanidm person create ${escapeShellArg name} \
                    ${escapeShellArg personSubmod.config.displayName}
                fi
                kanidm person update ${escapeShellArg name} ${escapeShellArgs updateArgs}
              ''
              + flip concatMapStrings personSubmod.config.groups (group: ''
                kanidm group add-members ${escapeShellArg group} ${escapeShellArg name}
              '')
            else ''
              if oauth2_system_exists ${escapeShellArg name}; then
                kanidm group delete ${escapeShellArg name}
              fi
            ''
          );

          present = mkPresentOption "person";

          displayName = mkOption {
            description = "Display name";
            type = types.str;
            example = "My User";
          };

          legalName = mkOption {
            description = "Full legal name";
            type = types.nullOr types.str;
            example = "Jane Doe";
            default = null;
          };

          mailAddresses = mkOption {
            description = "Mail addresses. First given address is considered the primary address.";
            type = types.listOf types.str;
            example = ["jane.doe@example.com"];
            default = [];
          };

          groups = mkOption {
            description = "List of kanidm groups to which this user belongs.";
            type = types.listOf types.str;
            default = [];
          };
        };
      }));
    };

    groups = mkOption {
      description = "Provisioning of kanidm groups";
      default = {};
      type = types.attrsOf (types.submodule (groupSubmod: let
        inherit (groupSubmod.module._args) name;
      in {
        options = {
          _script = mkScript (
            if groupSubmod.config.present
            then ''
              if ! group_exists ${escapeShellArg name}; then
                kanidm group create ${escapeShellArg name}
              fi
            ''
            else ''
              if group_exists ${escapeShellArg name}; then
                kanidm group delete ${escapeShellArg name}
              fi
            ''
          );

          present = mkPresentOption "group";
        };
      }));
    };

    systems.oauth2 = mkOption {
      description = "Provisioning of oauth2 systems";
      default = {};
      type = types.attrsOf (types.submodule (oauth2Submod: let
        inherit (oauth2Submod.module._args) name;
      in {
        options = {
          _script = mkScript (
            if oauth2Submod.config.present
            then
              ''
                if ! oauth2_system_exists ${escapeShellArg name}; then
                  kanidm system oauth2 create \
                    ${escapeShellArg name} \
                    ${escapeShellArg oauth2Submod.config.displayName} \
                    ${escapeShellArg oauth2Submod.config.originUrl}
                  needs_rewrite=1
                fi
              ''
              + concatLines (flip mapAttrsToList oauth2Submod.config.scopeMaps (group: scopes: ''
                kanidm system oauth2 update-scope-map ${escapeShellArg name} \
                  ${escapeShellArg group} ${escapeShellArgs scopes}
              ''))
              + concatLines (flip mapAttrsToList oauth2Submod.config.supplementaryScopeMaps (group: scopes: ''
                kanidm system oauth2 update-sup-scope-map ${escapeShellArg name} \
                  ${escapeShellArg group} ${escapeShellArgs scopes}
              ''))
            else ''
              if oauth2_system_exists ${escapeShellArg name}; then
                kanidm group delete ${escapeShellArg name}
              fi
            ''
          );

          present = mkPresentOption "oauth2 system";

          displayName = mkOption {
            description = "Display name";
            type = types.str;
            example = "Some Service";
          };

          originUrl = mkOption {
            description = "The basic secret to use for this service. If null, the random secret generated by kanidm will not be touched. Do NOT use a path from the nix store here!";
            type = types.str;
            example = "https://someservice.example.com/";
          };

          basicSecretFile = mkOption {
            description = "The basic secret to use for this service. If null, the random secret generated by kanidm will not be touched. Do NOT use a path from the nix store here!";
            type = types.nullOr types.path;
            example = "/run/secrets/some-oauth2-basic-secret";
            default = null;
          };

          scopeMaps = mkOption {
            description = "Maps kanidm groups to provided scopes. See [Scope Relations](https://kanidm.github.io/kanidm/stable/integrations/oauth2.html#scope-relationships) for more information.";
            type = types.attrsOf types.str;
            default = {};
          };

          supplementaryScopeMaps = mkOption {
            description = "Maps kanidm groups to provided supplementary scopes.  See [Scope Relations](https://kanidm.github.io/kanidm/stable/integrations/oauth2.html#scope-relationships) for more information.";
            type = types.attrsOf types.str;
            default = {};
          };
        };
      }));
    };
  };

  config = mkIf (cfg.enableServer && cfg.provision.enable) {
    assertions =
      flip mapAttrsToList cfg.provision.persons (person: personCfg: let
        unknownGroups = subtractLists (attrNames cfg.provision.groups) personCfg.groups;
      in {
        assertion = unknownGroups == [];
        message = "kanidm: provision.persons.${person}.groups: Refers to unknown groups: ${unknownGroups}";
      })
      + concatLists (flip mapAttrsToList cfg.provision.systems.oauth2 (oauth2: oauth2Cfg: [
        (let
          unknownGroups = subtractLists (attrNames cfg.provision.groups) (attrNames oauth2Cfg.scopeMaps);
        in {
          assertion = unknownGroups == [];
          message = "kanidm: provision.systems.oauth2.${oauth2}.scopeMaps: Refers to unknown groups: ${unknownGroups}";
        })
        (let
          unknownGroups = subtractLists (attrNames cfg.provision.groups) (attrNames oauth2Cfg.supplementaryScopeMaps);
        in {
          assertion = unknownGroups == [];
          message = "kanidm: provision.systems.oauth2.${oauth2}.supplementaryScopeMaps: Refers to unknown groups: ${unknownGroups}";
        })
      ]));

    systemd.services.kanidm = {
      serviceConfig.ExecStartPost =
        [provisioningScript]
        # Only the restarter runs with elevated privileges
        ++ optional (cfg.provision.systems.oauth2 != {}) "+${restarterScript}";

      preStart = let
        mappingsJson = pkgs.writeText "mappings.json" (builtins.toJSON {
          account_secrets.admin = cfg.provision.adminPasswordFile;
          oauth2_basic_secrets = mapAttrs (_: x: v.basicSecretFile) cfg.provision.systems.oauth2;
        });
      in ''
        if ! test -e ${escapeShellArg cfg.serverSettings.db_path}; then
          touch "$STATE_DIRECTORY/.first_startup"
        else
          ${getExe pkgs.kanidm-secret-manipulator} ${escapeShellArg cfg.serverSettings.db_path} ${tokenMappings}
        fi
      '';
    };
  };
}
