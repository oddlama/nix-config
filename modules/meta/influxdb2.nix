{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatMap
    concatMapStrings
    count
    elem
    escapeShellArg
    escapeShellArgs
    filter
    flip
    genAttrs
    getExe
    hasAttr
    head
    literalExpression
    mkBefore
    mkEnableOption
    mkIf
    mkOption
    optional
    optionalString
    optionals
    types
    unique
    ;

  format = pkgs.formats.json {};
  cfg = config.services.influxdb2;
  configFile = format.generate "config.json" cfg.settings;

  # A helper utility to allow provisioning tokens with deterministic secrets
  tokenManipulator = pkgs.buildGoModule rec {
    pname = "influxdb-token-manipulator";
    version = "1.0.0";

    src = pkgs.fetchFromGitHub {
      owner = "oddlama";
      repo = "influxdb-token-manipulator";
      rev = "v${version}";
      hash = "sha256-yKIvDNwwFb2teU7JvI92ie61m39VtrOYdeUz0v8uU3E=";
    };
    vendorHash = "sha256-zBZk7JbNILX18g9+2ukiESnFtnIVWhdN/J/MBhIITh8=";

    postPatch = ''
      sed -i '/Add token secrets here/ r ${
        pkgs.writeText "influxdb-token-paths" (concatMapStrings
          (x: ''"${x.id}": "${x.tokenFile}",''\n'')
          (filter (x: x.tokenFile != null) cfg.provision.ensureApiTokens))
      }' main.go
    '';

    meta = with lib; {
      description = "Utility program to manipulate influxdb api tokens for declarative setups";
      license = with licenses; [mit];
      maintainers = with maintainers; [oddlama];
    };
  };

  provisioningScript = pkgs.writeShellScript "post-start-provision" (''
      set -euo pipefail
      export INFLUX_HOST="http://"${escapeShellArg (cfg.settings.http-bind-address or "localhost:8086")}

      # Wait for the influxdb server to come online
      count=0
      while ! influx ping &>/dev/null; do
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

      # Do the initial database setup. Pass /dev/null as configs-path to
      # avoid saving the token as the active config.
      if test -e "$STATE_DIRECTORY/.first_startup"; then
        influx setup \
          --configs-path /dev/null \
          --org ${escapeShellArg cfg.provision.initialSetup.organization} \
          --bucket ${escapeShellArg cfg.provision.initialSetup.bucket} \
          --username ${escapeShellArg cfg.provision.initialSetup.username} \
          --password "$(< "$CREDENTIALS_DIRECTORY/admin-password")" \
          --token "$(< "$CREDENTIALS_DIRECTORY/admin-token")" \
          --retention ${escapeShellArg cfg.provision.initialSetup.retention} \
          --force >/dev/null

        rm -f "$STATE_DIRECTORY/.first_startup"
      fi

      export INFLUX_TOKEN=$(< "$CREDENTIALS_DIRECTORY/admin-token")

      ${concatMapStrings (x: x._script) cfg.provision.deleteApiTokens}
      ${concatMapStrings (x: x._script) cfg.provision.deleteReplications}
      ${concatMapStrings (x: x._script) cfg.provision.deleteRemotes}
      ${concatMapStrings (x: x._script) cfg.provision.deleteUsers}
      ${concatMapStrings (x: x._script) cfg.provision.deleteBuckets}
      ${concatMapStrings (x: x._script) cfg.provision.deleteOrganizations}

      ${concatMapStrings (x: x._script) cfg.provision.ensureOrganizations}
      ${concatMapStrings (x: x._script) cfg.provision.ensureBuckets}
      ${concatMapStrings (x: x._script) cfg.provision.ensureUsers}
      ${concatMapStrings (x: x._script) cfg.provision.ensureRemotes}
      ${concatMapStrings (x: x._script) cfg.provision.ensureReplications}
      ${concatMapStrings (x: x._script) cfg.provision.ensureApiTokens}
    ''
    + optionalString (cfg.provision.ensureApiTokens != []) ''
      if [[ ''${any_tokens_created-0} == 1 ]]; then
        echo "Created new tokens, queueing service restart so we can manipulate secrets"
        touch "$STATE_DIRECTORY/.needs_restart"
      fi
    '');
  restarterScript = pkgs.writeShellScript "post-start-restarter" ''
    set -euo pipefail
    if test -e "$STATE_DIRECTORY/.needs_restart"; then
      rm -f "$STATE_DIRECTORY/.needs_restart"
      systemctl restart influxdb2
    fi
  '';
in {
  options = {
    services.influxdb2 = {
      enable = mkEnableOption (lib.mdDoc "the influxdb2 server");

      package = mkOption {
        default = pkgs.influxdb2-server;
        defaultText = literalExpression "pkgs.influxdb2";
        description = lib.mdDoc "influxdb2 derivation to use.";
        type = types.package;
      };

      settings = mkOption {
        default = {};
        description = lib.mdDoc ''configuration options for influxdb2, see <https://docs.influxdata.com/influxdb/v2.0/reference/config-options> for details.'';
        inherit (format) type;
      };

      provision = {
        enable = mkEnableOption "initial database setup and provisioning";

        initialSetup = {
          organization = mkOption {
            type = types.str;
            example = "main";
            description = "Primary organization name";
          };

          bucket = mkOption {
            type = types.str;
            example = "example";
            description = "Primary bucket name";
          };

          username = mkOption {
            type = types.str;
            default = "admin";
            description = "Primary username";
          };

          retention = mkOption {
            type = types.str;
            default = "0";
            description = ''
              The duration for which the bucket will retain data (0 is infinite).
              Accepted units are `ns` (nanoseconds), `us` or `µs` (microseconds), `ms` (milliseconds),
              `s` (seconds), `m` (minutes), `h` (hours), `d` (days) and `w` (weeks).
            '';
          };

          passwordFile = mkOption {
            type = types.path;
            description = "Password for primary user. Don't use a file from the nix store!";
          };

          tokenFile = mkOption {
            type = types.path;
            description = "API Token to set for the admin user. Don't use a file from the nix store!";
          };
        };

        deleteOrganizations = mkOption {
          description = "List of organizations that should be deleted.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              name = mkOption {
                description = "Name of the organization to delete.";
                type = types.str;
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = ''
                  if id=$(
                    influx org list --json --name ${escapeShellArg config.name} 2>/dev/null \
                      | jq -r ".[0].id"
                  ); then
                    influx org delete --id "$id" >/dev/null
                    echo "Deleted org name="${escapeShellArg config.name}
                  fi
                '';
              };
            };
          }));
        };

        deleteBuckets = mkOption {
          description = "List of buckets that should be deleted.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              org = mkOption {
                description = "The organization to which the bucket belongs.";
                type = types.str;
              };

              name = mkOption {
                description = "Name of the bucket.";
                type = types.str;
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = ''
                  if id=$(
                    influx bucket list --json --org ${escapeShellArg config.org} --name ${escapeShellArg config.name} 2>/dev/null \
                      | jq -r ".[0].id"
                  ); then
                    influx bucket delete --id "$id" >/dev/null
                    echo "Deleted bucket org="${escapeShellArg config.org}" name="${escapeShellArg config.name}
                  fi
                '';
              };
            };
          }));
        };

        deleteUsers = mkOption {
          description = "List of users that should be deleted.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              name = mkOption {
                description = "Name of the user to delete.";
                type = types.str;
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = ''
                  if id=$(
                    influx user list --json --name ${escapeShellArg config.name} 2>/dev/null \
                      | jq -r ".[0].id"
                  ); then
                    influx user delete --id "$id" >/dev/null
                    echo "Deleted user name="${escapeShellArg config.name}
                  fi
                '';
              };
            };
          }));
        };

        deleteRemotes = mkOption {
          description = "List of remotes that should be deleted.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              org = mkOption {
                description = "The organization to which the remote belongs.";
                type = types.str;
              };

              name = mkOption {
                description = "Name of the remote.";
                type = types.str;
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = ''
                  if id=$(
                    influx remote list --json --org ${escapeShellArg config.org} --name ${escapeShellArg config.name} 2>/dev/null \
                      | jq -r ".[0].id"
                  ); then
                    influx remote delete --id "$id" >/dev/null
                    echo "Deleted remote org="${escapeShellArg config.org}" name="${escapeShellArg config.name}
                  fi
                '';
              };
            };
          }));
        };

        deleteReplications = mkOption {
          description = "List of replications that should be deleted.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              org = mkOption {
                description = "The organization to which the replication belongs.";
                type = types.str;
              };

              name = mkOption {
                description = "Name of the replication.";
                type = types.str;
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = ''
                  if id=$(
                    influx replication list --json --org ${escapeShellArg config.org} --name ${escapeShellArg config.name} 2>/dev/null \
                      | jq -r ".[0].id"
                  ); then
                    influx replication delete --id "$id" >/dev/null
                    echo "Deleted replication org="${escapeShellArg config.org}" name="${escapeShellArg config.name}
                  fi
                '';
              };
            };
          }));
        };

        deleteApiTokens = mkOption {
          description = "List of api tokens that should be deleted.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              id = mkOption {
                description = "A unique identifier for this token. See `ensureApiTokens.*.name` for more information.";
                readOnly = true;
                default = builtins.substring 0 32 (builtins.hashString "sha256" "${config.user}:${config.org}:${config.name}");
                defaultText = "<a hash derived from user, org and name>";
                type = types.str;
              };

              org = mkOption {
                description = "The organization to which the api token belongs.";
                type = types.str;
              };

              name = mkOption {
                description = "Name of the api token.";
                type = types.str;
              };

              user = mkOption {
                description = "The user to which the api token belongs.";
                type = types.str;
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = ''
                  if id=$(
                    influx auth list --json --org ${escapeShellArg config.org} 2>/dev/null \
                      | jq -r '.[] | select(.description | contains("${config.id}")) | .id'
                  ) && [[ -n "$id" ]]; then
                    influx auth delete --id "$id" >/dev/null
                    echo "Deleted api token id="${escapeShellArg config.id}
                  fi
                '';
              };
            };
          }));
        };

        ensureOrganizations = mkOption {
          description = "List of organizations that should be created. Future changes to the name will not be reflected.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              name = mkOption {
                description = "Name of the organization.";
                type = types.str;
              };

              description = mkOption {
                description = "Optional description for the organization.";
                default = null;
                type = types.nullOr types.str;
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = let
                  listArgs = ["--name" config.name];
                  updateArgs = optionals (config.description != null) [
                    "--description"
                    config.description
                  ];
                  createArgs = listArgs ++ updateArgs;
                in ''
                  if id=$(
                    influx org list --json ${escapeShellArgs listArgs} 2>/dev/null \
                      | jq -r ".[0].id"
                  ); then
                    influx org update --id "$id" ${escapeShellArgs updateArgs} >/dev/null
                  else
                    influx org create ${escapeShellArgs createArgs} >/dev/null
                    echo "Created org name="${escapeShellArg config.name}
                  fi
                '';
              };
            };
          }));
        };

        ensureBuckets = mkOption {
          description = "List of buckets that should be created. Future changes to the name or org will not be reflected.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              org = mkOption {
                description = "The organization the bucket belongs to.";
                type = types.str;
              };

              name = mkOption {
                description = "Name of the bucket.";
                type = types.str;
              };

              description = mkOption {
                description = "Optional description for the bucket.";
                default = null;
                type = types.nullOr types.str;
              };

              retention = mkOption {
                type = types.str;
                default = "0";
                description = ''
                  The duration for which the bucket will retain data (0 is infinite).
                  Accepted units are `ns` (nanoseconds), `us` or `µs` (microseconds), `ms` (milliseconds),
                  `s` (seconds), `m` (minutes), `h` (hours), `d` (days) and `w` (weeks).
                '';
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = let
                  listArgs = [
                    "--org"
                    config.org
                    "--name"
                    config.name
                  ];
                  updateArgs =
                    [
                      "--retention"
                      config.retention
                    ]
                    ++ optionals (config.description != null) [
                      "--description"
                      config.description
                    ];
                  createArgs = listArgs ++ updateArgs;
                in ''
                  if id=$(
                    influx bucket list --json ${escapeShellArgs listArgs} 2>/dev/null \
                      | jq -r ".[0].id"
                  ); then
                    influx bucket update --id "$id" ${escapeShellArgs updateArgs} >/dev/null
                  else
                    influx bucket create ${escapeShellArgs createArgs} >/dev/null
                    echo "Created bucket org="${escapeShellArg config.org}" name="${escapeShellArg config.name}
                  fi
                '';
              };
            };
          }));
        };

        ensureUsers = mkOption {
          description = "List of users that should be created. Future changes to the name or primary org will not be reflected.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              org = mkOption {
                description = "Primary organization to which the user will be added as a member.";
                type = types.str;
              };

              name = mkOption {
                description = "Name of the user.";
                type = types.str;
              };

              passwordFile = mkOption {
                description = "Password for the user. If unset, the user will not be able to log in until a password is set by an operator! Don't use a file from the nix store!";
                type = types.nullOr types.path;
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = let
                  listArgs = ["--name" config.name];
                  createArgs =
                    listArgs
                    ++ [
                      "--org"
                      config.org
                    ];
                in
                  ''
                    if id=$(
                      influx user list --json ${escapeShellArgs listArgs} 2>/dev/null \
                        | jq -r ".[0].id"
                    ); then
                      true # No updateable args
                    else
                      influx user create ${escapeShellArgs createArgs} >/dev/null
                      echo "Created user name="${escapeShellArg config.name}
                    fi
                  ''
                  + optionalString (config.passwordFile != null) ''
                    influx user password ${escapeShellArgs listArgs} \
                      --password "$(< ${escapeShellArg config.passwordFile})" >/dev/null
                  '';
              };
            };
          }));
        };

        ensureRemotes = mkOption {
          description = "List of remotes that should be created. Future changes to the name, org or remoteOrg will not be reflected.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              org = mkOption {
                description = "Organization to which the remote belongs.";
                type = types.str;
              };

              name = mkOption {
                description = "Name of the remote.";
                type = types.str;
              };

              description = mkOption {
                description = "Optional description for the remote.";
                default = null;
                type = types.nullOr types.str;
              };

              remoteUrl = mkOption {
                description = "The url where the remote instance can be reached";
                type = types.str;
              };

              remoteOrg = mkOption {
                description = ''
                  Corresponding remote organization. If this is used instead of `remoteOrgId`,
                  the remote organization id must be queried first which means the provided remote
                  token must have the `read-orgs` flag.
                '';
                type = types.nullOr types.str;
                default = null;
              };

              remoteOrgId = mkOption {
                description = "Corresponding remote organization id.";
                type = types.nullOr types.str;
                default = null;
              };

              remoteTokenFile = mkOption {
                type = types.path;
                description = "API token used to authenticate with the remote.";
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = let
                  listArgs = [
                    "--name"
                    config.name
                    "--org"
                    config.org
                  ];
                  updateArgs =
                    ["--remote-url" config.remoteUrl]
                    ++ optionals (config.remoteOrgId != null) ["--remote-org-id" config.remoteOrgId]
                    ++ optionals (config.description != null) ["--description" config.description];
                  createArgs = listArgs ++ updateArgs;
                in
                  ''
                    if id=$(
                      influx remote list --json ${escapeShellArgs listArgs} 2>/dev/null \
                        | jq -r ".[0].id"
                    ); then
                      influx remote update --id "$id" ${escapeShellArgs updateArgs} >/dev/null \
                        --remote-api-token "$(< ${escapeShellArg config.remoteTokenFile})"
                    else
                      extraArgs=()
                  ''
                  + optionalString (config.remoteOrg != null) ''
                    remote_org_id=$(
                      influx org list --json \
                        --host ${escapeShellArg config.remoteUrl} \
                        --token "$(< ${escapeShellArg config.remoteTokenFile})" \
                        --name ${escapeShellArg config.remoteOrg} \
                        | jq -r ".[0].id"
                    )
                    extraArgs+=("--remote-org-id" "$remote_org_id")
                  ''
                  + ''
                      influx remote create ${escapeShellArgs createArgs} >/dev/null \
                        --remote-api-token "$(< ${escapeShellArg config.remoteTokenFile})" \
                        "''${extraArgs[@]}"
                      echo "Created remote org="${escapeShellArg config.org}" name="${escapeShellArg config.name}
                    fi
                  '';
              };
            };
          }));
        };

        ensureReplications = mkOption {
          description = "List of replications that should be created. Future changes to name, org or buckets will not be reflected.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              org = mkOption {
                description = "Organization to which the replication belongs.";
                type = types.str;
              };

              name = mkOption {
                description = "Name of the remote.";
                type = types.str;
              };

              remote = mkOption {
                description = "The remote to replicate to.";
                type = types.str;
              };

              localBucket = mkOption {
                description = "The local bucket to replicate from.";
                type = types.str;
              };

              remoteBucket = mkOption {
                description = "The remte bucket to replicate to.";
                type = types.str;
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = let
                  listArgs = [
                    "--name"
                    config.name
                    "--org"
                    config.org
                  ];
                  createArgs =
                    listArgs
                    ++ [
                      "--remote-bucket"
                      config.remoteBucket
                    ];
                in ''
                  if id=$(
                    influx replication list --json ${escapeShellArgs listArgs} 2>/dev/null \
                      | jq -r ".[0].id"
                  ); then
                    true # No updateable args
                  else
                    remote_id=$(
                      influx remote list --json --org ${escapeShellArg config.org} --name ${escapeShellArg config.remote} \
                        | jq -r ".[0].id"
                    )
                    local_bucket_id=$(
                      influx bucket list --json --org ${escapeShellArg config.org} --name ${escapeShellArg config.localBucket} \
                        | jq -r ".[0].id"
                    )
                    influx replication create ${escapeShellArgs createArgs} >/dev/null \
                      --remote-id "$remote_id" \
                      --local-bucket-id "$local_bucket_id"
                    echo "Created replication org="${escapeShellArg config.org}" name="${escapeShellArg config.name}
                  fi
                '';
              };
            };
          }));
        };

        ensureApiTokens = mkOption {
          description = "List of api tokens that should be created. Future changes to existing tokens cannot be reflected.";
          default = [];
          type = types.listOf (types.submodule ({config, ...}: {
            options = {
              id = mkOption {
                description = "A unique identifier for this token. Since influx doesn't store names for tokens, this will be hashed and appended to the description to identify the token.";
                readOnly = true;
                default = builtins.substring 0 32 (builtins.hashString "sha256" "${config.user}:${config.org}:${config.name}");
                defaultText = "<a hash derived from user, org and name>";
                type = types.str;
              };

              org = mkOption {
                description = "Organization to which the token belongs.";
                type = types.str;
              };

              name = mkOption {
                description = "A name to identify this token. Not an actual influxdb attribute, but needed to calculate a stable id (see `id`).";
                type = types.str;
              };

              user = mkOption {
                description = "The user to which the token belongs.";
                type = types.str;
              };

              description = mkOption {
                description = ''
                  Optional description for the api token.
                  Note that the actual token will always be created with a description regardless
                  of whether this is given or not. A unique suffix has to be appended to later identify
                  the token to track whether it has already been created.
                '';
                default = null;
                type = types.nullOr types.str;
              };

              tokenFile = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = "The token value. If not given, influx will automatically generate one.";
              };

              operator = mkOption {
                description = "Grants all permissions in all organizations.";
                default = false;
                type = types.bool;
              };

              allAccess = mkOption {
                description = "Grants all permissions in the associated organization.";
                default = false;
                type = types.bool;
              };

              readPermissions = mkOption {
                description = ''
                  The read permissions to include for this token. Access is usually granted only
                  for resources in the associated organization.

                  Available permissions are `authorizations`, `buckets`, `dashboards`,
                  `orgs`, `tasks`, `telegrafs`, `users`, `variables`, `secrets`, `labels`, `views`,
                  `documents`, `notificationRules`, `notificationEndpoints`, `checks`, `dbrp`,
                  `annotations`, `sources`, `scrapers`, `notebooks`, `remotes`, `replications`.

                  Refer to `influx auth create --help` for a full list with descriptions.

                  `buckets` grants read access to all associated buckets. Use `readBuckets` to define
                  more granular access permissions.
                '';
                default = [];
                type = types.listOf types.str;
              };

              writePermissions = mkOption {
                description = ''
                  The read permissions to include for this token. Access is usually granted only
                  for resources in the associated organization.

                  Available permissions are `authorizations`, `buckets`, `dashboards`,
                  `orgs`, `tasks`, `telegrafs`, `users`, `variables`, `secrets`, `labels`, `views`,
                  `documents`, `notificationRules`, `notificationEndpoints`, `checks`, `dbrp`,
                  `annotations`, `sources`, `scrapers`, `notebooks`, `remotes`, `replications`.

                  Refer to `influx auth create --help` for a full list with descriptions.

                  `buckets` grants write access to all associated buckets. Use `writeBuckets` to define
                  more granular access permissions.
                '';
                default = [];
                type = types.listOf types.str;
              };

              readBuckets = mkOption {
                description = "The organization's buckets which should be allowed to be read";
                default = [];
                type = types.listOf types.str;
              };

              writeBuckets = mkOption {
                description = "The organization's buckets which should be allowed to be written";
                default = [];
                type = types.listOf types.str;
              };

              _script = mkOption {
                internal = true;
                readOnly = true;
                type = types.str;
                default = let
                  listArgs = [
                    "--user"
                    config.user
                    "--org"
                    config.org
                  ];
                  fullDescription =
                    "${config.name} - "
                    + optionalString (config.description != null) "${config.description} - "
                    + config.id;
                  createArgs =
                    listArgs
                    ++ ["--description" fullDescription]
                    ++ optional config.operator "--operator"
                    ++ optional config.allAccess "--all-access"
                    ++ map (x: "--read-${x}") config.readPermissions
                    ++ map (x: "--write-${x}") config.writePermissions;
                in
                  ''
                    if id=$(
                      influx auth list --json --org ${escapeShellArg config.org} 2>/dev/null \
                        | jq -r '.[] | select(.description | contains("${config.id}")) | .id'
                    ) && [[ -n "$id" ]]; then
                      true # No updateable args
                    else
                      declare -A bucketIds
                  ''
                  + flip concatMapStrings (unique (config.readBuckets ++ config.writeBuckets)) (bucket: ''
                    bucketIds[${escapeShellArg bucket}]=$(
                      influx bucket list --json --org ${escapeShellArg config.org} --name ${escapeShellArg bucket} \
                        | jq -r ".[0].id"
                    )
                  '')
                  + ''
                      extraArgs=(
                        ${flip concatMapStrings config.readBuckets (bucket: ''"--read-bucket" "''${bucketIds[${escapeShellArg bucket}]}"''\n'')}
                        ${flip concatMapStrings config.writeBuckets (bucket: ''"--write-bucket" "''${bucketIds[${escapeShellArg bucket}]}"''\n'')}
                      )
                      influx auth create ${escapeShellArgs createArgs} >/dev/null "''${extraArgs[@]}"
                      echo "Created api token org="${escapeShellArg config.org}" user="${escapeShellArg config.user}
                      ${
                      # Force restart to update tokens if necessary
                      optionalString (config.tokenFile != null) "any_tokens_created=1"
                    }
                    fi
                  '';
              };
            };
          }));
        };
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = let
      validPermissions = flip genAttrs (x: true) [
        "authorizations"
        "buckets"
        "dashboards"
        "orgs"
        "tasks"
        "telegrafs"
        "users"
        "variables"
        "secrets"
        "labels"
        "views"
        "documents"
        "notificationRules"
        "notificationEndpoints"
        "checks"
        "dbrp"
        "annotations"
        "sources"
        "scrapers"
        "notebooks"
        "remotes"
        "replications"
      ];

      knownOrgs = map (x: x.name) cfg.provision.ensureOrganizations;
      knownRemotes = map (x: x.name) cfg.provision.ensureRemotes;
      knownBucketsFor = org: map (x: x.name) (filter (x: x.org == org) cfg.provision.ensureBuckets);
    in
      [
        {
          assertion = !(hasAttr "bolt-path" cfg.settings) && !(hasAttr "engine-path" cfg.settings);
          message = "services.influxdb2.config: bolt-path and engine-path should not be set as they are managed by systemd";
        }
      ]
      ++ flip concatMap cfg.provision.ensureBuckets (bucket: [
        {
          assertion = elem bucket.org knownOrgs;
          message = "The influxdb bucket '${bucket.name}' refers to an unknown organization '${bucket.org}'.";
        }
      ])
      ++ flip concatMap cfg.provision.ensureUsers (user: [
        {
          assertion = elem user.org knownOrgs;
          message = "The influxdb user '${user.name}' refers to an unknown organization '${user.org}'.";
        }
      ])
      ++ flip concatMap cfg.provision.ensureRemotes (remote: [
        {
          assertion = (remote.remoteOrgId == null) != (remote.remoteOrg == null);
          message = "The influxdb remote '${remote.name}' must specify exactly one of remoteOrgId or remoteOrg.";
        }
        {
          assertion = elem remote.org knownOrgs;
          message = "The influxdb remote '${remote.name}' refers to an unknown organization '${remote.org}'.";
        }
      ])
      ++ flip concatMap cfg.provision.ensureReplications (replication: [
        {
          assertion = elem replication.remote knownRemotes;
          message = "The influxdb replication '${replication.name}' refers to an unknown remote '${replication.remote}'.";
        }
        (let
          remote = head (filter (x: x.name == replication.remote) cfg.provision.ensureRemotes);
        in {
          assertion = elem replication.localBucket (knownBucketsFor remote.org);
          message = "The influxdb replication '${replication.name}' refers to an unknown bucket '${replication.localBucket}' in organization '${remote.org}'.";
        })
      ])
      ++ flip concatMap cfg.provision.ensureApiTokens (apiToken: let
        validBuckets = flip genAttrs (x: true) (knownBucketsFor apiToken.org);
      in [
        {
          assertion = elem apiToken.org knownOrgs;
          message = "The influxdb apiToken '${apiToken.name}' refers to an unknown organization '${apiToken.org}'.";
        }
        {
          assertion =
            1
            == count (x: x) [
              apiToken.operator
              apiToken.allAccess
              (apiToken.readPermissions
                != []
                || apiToken.writePermissions != []
                || apiToken.readBuckets != []
                || apiToken.writeBuckets != [])
            ];
          message = "The influxdb apiToken '${apiToken.name}' in organization '${apiToken.org}' uses mutually exclusive options. The `operator` and `allAccess` options are mutually exclusive with each other and the granular permission settings.";
        }
        (let
          unknownBuckets = filter (x: !hasAttr x validBuckets) apiToken.readBuckets;
        in {
          assertion = unknownBuckets == [];
          message = "The influxdb apiToken '${apiToken.name}' refers to invalid buckets in readBuckets: ${toString unknownBuckets}";
        })
        (let
          unknownBuckets = filter (x: !hasAttr x validBuckets) apiToken.writeBuckets;
        in {
          assertion = unknownBuckets == [];
          message = "The influxdb apiToken '${apiToken.name}' refers to invalid buckets in writeBuckets: ${toString unknownBuckets}";
        })
        (let
          unknownPerms = filter (x: !hasAttr x validPermissions) apiToken.readPermissions;
        in {
          assertion = unknownPerms == [];
          message = "The influxdb apiToken '${apiToken.name}' refers to invalid read permissions: ${toString unknownPerms}";
        })
        (let
          unknownPerms = filter (x: !hasAttr x validPermissions) apiToken.writePermissions;
        in {
          assertion = unknownPerms == [];
          message = "The influxdb apiToken '${apiToken.name}' refers to invalid write permissions: ${toString unknownPerms}";
        })
      ]);

    systemd.services.influxdb2 = {
      description = "InfluxDB is an open-source, distributed, time series database";
      documentation = ["https://docs.influxdata.com/influxdb/"];
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      environment = {
        INFLUXD_CONFIG_PATH = configFile;
        ZONEINFO = "${pkgs.tzdata}/share/zoneinfo";
      };
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/influxd --bolt-path \${STATE_DIRECTORY}/influxd.bolt --engine-path \${STATE_DIRECTORY}/engine";
        StateDirectory = "influxdb2";
        User = "influxdb2";
        Group = "influxdb2";
        CapabilityBoundingSet = "";
        SystemCallFilter = "@system-service";
        LimitNOFILE = 65536;
        KillMode = "control-group";
        Restart = "on-failure";
        LoadCredential = [
          "admin-password:${cfg.provision.initialSetup.passwordFile}"
          "admin-token:${cfg.provision.initialSetup.tokenFile}"
        ];

        ExecStartPost = mkIf cfg.provision.enable (
          [provisioningScript]
          ++
          # Only the restarter runs with elevated privileges
          optional (cfg.provision.ensureApiTokens != []) "+${restarterScript}"
        );
      };

      path = [
        pkgs.influxdb2-cli
        pkgs.jq
      ];

      # Mark if this is the first startup so postStart can do the initial setup
      preStart = mkIf cfg.provision.enable ''
        if ! test -e "$STATE_DIRECTORY/influxd.bolt"; then
          touch "$STATE_DIRECTORY/.first_startup"
        else
          # Manipulate provisioned api tokens if necessary
          ${tokenManipulator}/bin/influxdb-token-manipulator "$STATE_DIRECTORY/influxd.bolt"
        fi
      '';
    };

    users.extraUsers.influxdb2 = {
      isSystemUser = true;
      group = "influxdb2";
    };

    users.extraGroups.influxdb2 = {};
  };

  meta.maintainers = with lib.maintainers; [nickcao oddlama];
}
