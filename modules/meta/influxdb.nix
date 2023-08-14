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

  cfg = config.services.influxdb2;
in {
  options.services.influxdb2 = {
    initialSetup = {
      enable = mkEnableOption "initial database setup";
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
        type = types.nullOr types.path;
        default = null;
        description = "API Token for the admin user. If not given, influx will automatically generate one.";
      };
    };

    deleteOrganizations = mkOption {
      description = "List of organizations that should be deleted.";
      default = [];
      type = types.listOf types.str;
    };

    deleteBuckets = mkOption {
      description = "List of buckets that should be deleted.";
      default = [];
      type = types.listOf (types.submodule {
        options.name = mkOption {
          description = "Name of the bucket.";
          type = types.str;
        };

        options.org = mkOption {
          description = "The organization to which the bucket belongs.";
          type = types.str;
        };
      });
    };

    deleteUsers = mkOption {
      description = "List of users that should be deleted.";
      default = [];
      type = types.listOf types.str;
    };

    deleteRemotes = mkOption {
      description = "List of remotes that should be deleted.";
      default = [];
      type = types.listOf (types.submodule {
        options.name = mkOption {
          description = "Name of the remote.";
          type = types.str;
        };

        options.org = mkOption {
          description = "The organization to which the remote belongs.";
          type = types.str;
        };
      });
    };

    deleteReplications = mkOption {
      description = "List of replications that should be deleted.";
      default = [];
      type = types.listOf (types.submodule {
        options.name = mkOption {
          description = "Name of the replication.";
          type = types.str;
        };

        options.org = mkOption {
          description = "The organization to which the replication belongs.";
          type = types.str;
        };
      });
    };

    deleteApiTokens = mkOption {
      description = "List of api tokens that should be deleted.";
      default = [];
      type = types.listOf (types.submodule ({config, ...}: {
        options.id = mkOption {
          description = "A unique identifier for this token. See `ensureApiTokens.*.name` for more information.";
          readOnly = true;
          default = builtins.substring 0 32 (builtins.hashString "sha256" "${config.user}:${config.org}:${config.name}");
          type = types.str;
        };

        options.name = mkOption {
          description = "Name of the api token.";
          type = types.str;
        };

        options.org = mkOption {
          description = "The organization to which the api token belongs.";
          type = types.str;
        };

        options.user = mkOption {
          description = "The user to which the api token belongs.";
          type = types.str;
        };
      }));
    };

    ensureOrganizations = mkOption {
      description = "List of organizations that should be created. Future changes to the name will not be reflected.";
      default = [];
      type = types.listOf (types.submodule {
        options.name = mkOption {
          description = "Name of the organization.";
          type = types.str;
        };

        options.description = mkOption {
          description = "Optional description for the organization.";
          default = null;
          type = types.nullOr types.str;
        };
      });
    };

    ensureBuckets = mkOption {
      description = "List of buckets that should be created. Future changes to the name or org will not be reflected.";
      default = [];
      type = types.listOf (types.submodule {
        options.name = mkOption {
          description = "Name of the bucket.";
          type = types.str;
        };

        options.org = mkOption {
          description = "The organization the bucket belongs to.";
          type = types.str;
        };

        options.description = mkOption {
          description = "Optional description for the bucket.";
          default = null;
          type = types.nullOr types.str;
        };

        options.retention = mkOption {
          type = types.str;
          default = "0";
          description = ''
            The duration for which the bucket will retain data (0 is infinite).
            Accepted units are `ns` (nanoseconds), `us` or `µs` (microseconds), `ms` (milliseconds),
            `s` (seconds), `m` (minutes), `h` (hours), `d` (days) and `w` (weeks).
          '';
        };
      });
    };

    ensureUsers = mkOption {
      description = "List of users that should be created. Future changes to the name or primary org will not be reflected.";
      default = [];
      type = types.listOf (types.submodule {
        options.name = mkOption {
          description = "Name of the user.";
          type = types.str;
        };

        options.org = mkOption {
          description = "Primary organization to which the user will be added as a member.";
          type = types.str;
        };

        options.passwordFile = mkOption {
          description = "Password for the user. If unset, the user will not be able to log in until a password is set by an operator! Don't use a file from the nix store!";
          type = types.nullOr types.path;
        };
      });
    };

    ensureRemotes = mkOption {
      description = "List of remotes that should be created. Future changes to the name, org or remoteOrg will not be reflected.";
      default = [];
      type = types.listOf (types.submodule {
        options.name = mkOption {
          description = "Name of the remote.";
          type = types.str;
        };

        options.org = mkOption {
          description = "Organization to which the remote belongs.";
          type = types.str;
        };

        options.description = mkOption {
          description = "Optional description for the remote.";
          default = null;
          type = types.nullOr types.str;
        };

        options.remoteUrl = mkOption {
          description = "The url where the remote instance can be reached";
          type = types.str;
        };

        options.remoteOrg = mkOption {
          description = ''
            Corresponding remote organization. If this is used instead of `remoteOrgId`,
            the remote organization id must be queried first which means the provided remote
            token must have the `read-orgs` flag.
          '';
          type = types.nullOr types.str;
          default = null;
        };

        options.remoteOrgId = mkOption {
          description = "Corresponding remote organization id.";
          type = types.nullOr types.str;
          default = null;
        };

        options.remoteTokenFile = mkOption {
          type = types.path;
          description = "API token used to authenticate with the remote.";
        };
      });
    };

    ensureReplications = mkOption {
      description = "List of replications that should be created. Future changes to name, org or buckets will not be reflected.";
      default = [];
      type = types.listOf (types.submodule {
        options.name = mkOption {
          description = "Name of the remote.";
          type = types.str;
        };

        options.org = mkOption {
          description = "Organization to which the replication belongs.";
          type = types.str;
        };

        options.remote = mkOption {
          description = "The remote to replicate to.";
          type = types.str;
        };

        options.localBucket = mkOption {
          description = "The local bucket to replicate from.";
          type = types.str;
        };

        options.remoteBucket = mkOption {
          description = "The remte bucket to replicate to.";
          type = types.str;
        };
      });
    };

    ensureApiTokens = mkOption {
      description = "List of api tokens that should be created. Future changes to existing tokens cannot be reflected.";
      default = [];
      type = types.listOf (types.submodule ({config, ...}: {
        options.id = mkOption {
          description = "A unique identifier for this token. Since influx doesn't store names for tokens, this will be hashed and appended to the description to identify the token.";
          readOnly = true;
          default = builtins.substring 0 32 (builtins.hashString "sha256" "${config.user}:${config.org}:${config.name}");
          type = types.str;
        };

        options.name = mkOption {
          description = "A name to identify this token. Not an actual influxdb attribute, but needed to calculate a stable id (see `id`).";
          type = types.str;
        };

        options.user = mkOption {
          description = "The user to which the token belongs.";
          type = types.str;
        };

        options.org = mkOption {
          description = "Organization to which the token belongs.";
          type = types.str;
        };

        options.description = mkOption {
          description = ''
            Optional description for the api token.
            Note that the actual token will always be created with a description regardless
            of whether this is given or not. A unique suffix has to be appended to later identify
            the token to track whether it has already been created.
          '';
          default = null;
          type = types.nullOr types.str;
        };

        options.operator = mkOption {
          description = "Grants all permissions in all organizations.";
          default = false;
          type = types.bool;
        };

        options.allAccess = mkOption {
          description = "Grants all permissions in the associated organization.";
          default = false;
          type = types.bool;
        };

        options.readPermissions = mkOption {
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

        options.writePermissions = mkOption {
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

        options.readBuckets = mkOption {
          description = "The organization's buckets which should be allowed to be read";
          default = [];
          type = types.listOf types.str;
        };

        options.writeBuckets = mkOption {
          description = "The organization's buckets which should be allowed to be written";
          default = [];
          type = types.listOf types.str;
        };
      }));
    };
  };

  config = mkIf (cfg.enable && cfg.initialSetup.enable) {
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

      knownOrgs = map (x: x.name) cfg.ensureOrganizations;
      knownRemotes = map (x: x.name) cfg.ensureRemotes;
      knownBucketsFor = org: map (x: x.name) (filter (x: x.org == org) cfg.ensureBuckets);
    in
      flip concatMap cfg.ensureBuckets (bucket: [
        {
          assertion = elem bucket.org knownOrgs;
          message = "The influxdb bucket '${bucket.name}' refers to an unknown organization '${bucket.org}'.";
        }
      ])
      ++ flip concatMap cfg.ensureUsers (user: [
        {
          assertion = elem user.org knownOrgs;
          message = "The influxdb user '${user.name}' refers to an unknown organization '${user.org}'.";
        }
      ])
      ++ flip concatMap cfg.ensureRemotes (remote: [
        {
          assertion = (remote.remoteOrgId == null) != (remote.remoteOrg == null);
          message = "The influxdb remote '${remote.name}' must specify exactly one of remoteOrgId or remoteOrg.";
        }
        {
          assertion = elem remote.org knownOrgs;
          message = "The influxdb remote '${remote.name}' refers to an unknown organization '${remote.org}'.";
        }
      ])
      ++ flip concatMap cfg.ensureReplications (replication: [
        {
          assertion = elem replication.remote knownRemotes;
          message = "The influxdb replication '${replication.name}' refers to an unknown remote '${replication.remote}'.";
        }
        (let
          remote = head (filter (x: x.name == replication.remote) cfg.ensureRemotes);
        in {
          assertion = elem replication.localBucket (knownBucketsFor remote.org);
          message = "The influxdb replication '${replication.name}' refers to an unknown bucket '${replication.localBucket}' in organization '${remote.org}'.";
        })
      ])
      ++ flip concatMap cfg.ensureApiTokens (apiToken: let
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
      # Mark if this is the first startup so postStart can do the initial setup
      preStart = ''
        if ! test -e "$STATE_DIRECTORY/influxd.bolt"; then
          touch "$STATE_DIRECTORY/.first_startup"
        fi
      '';

      postStart = let
        influxCli = "${pkgs.influxdb2-cli}/bin/influx"; # getExe pkgs.influxdb2-cli
      in
        ''
          set -euo pipefail
          export INFLUX_HOST="http://"${escapeShellArg config.services.influxdb2.settings.http-bind-address}

          # Wait for the influxdb server to come online
          count=0
          while ! ${influxCli} ping &>/dev/null; do
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

          if test -e "$STATE_DIRECTORY/.first_startup"; then
            # Do the initial database setup. Pass /dev/null as configs-path to
            # avoid saving the token as the active config.
            ${influxCli} setup \
              --configs-path /dev/null \
              --org ${escapeShellArg cfg.initialSetup.organization} \
              --bucket ${escapeShellArg cfg.initialSetup.bucket} \
              --username ${escapeShellArg cfg.initialSetup.username} \
              --password "$(< ${escapeShellArg cfg.initialSetup.passwordFile})" \
              --token "$(< ${escapeShellArg cfg.initialSetup.tokenFile})" \
              --retention ${escapeShellArg cfg.initialSetup.retention} \
              --force >/dev/null

            rm -f "$STATE_DIRECTORY/.first_startup"
          fi

          export INFLUX_TOKEN=$(< ${escapeShellArg cfg.initialSetup.tokenFile})
        ''
        + flip concatMapStrings cfg.deleteApiTokens (apiToken: ''
          if id=$(
            ${influxCli} auth list --json --org ${escapeShellArg apiToken.org} 2>/dev/null \
              | ${getExe pkgs.jq} -r '.[] | select(.description | contains("${apiToken.id}")) | .id'
          ) && [[ -n "$id" ]]; then
            ${influxCli} auth delete --id "$id" &>/dev/null
            echo "Deleted api token id="${escapeShellArg apiToken.id}
          fi
        '')
        + flip concatMapStrings cfg.deleteReplications (replication: ''
          if id=$(
            ${influxCli} replication list --json --org ${escapeShellArg replication.org} --name ${escapeShellArg replication.name} 2>/dev/null \
              | ${getExe pkgs.jq} -r ".[0].id"
          ); then
            ${influxCli} replication delete --id "$id" &>/dev/null
            echo "Deleted replication org="${escapeShellArg replication.org}" name="${escapeShellArg replication.name}
          fi
        '')
        + flip concatMapStrings cfg.deleteRemotes (remote: ''
          if id=$(
            ${influxCli} remote list --json --org ${escapeShellArg remote.org} --name ${escapeShellArg remote.name} 2>/dev/null \
              | ${getExe pkgs.jq} -r ".[0].id"
          ); then
            ${influxCli} remote delete --id "$id" &>/dev/null
            echo "Deleted remote org="${escapeShellArg remote.org}" name="${escapeShellArg remote.name}
          fi
        '')
        + flip concatMapStrings cfg.deleteUsers (user: ''
          if id=$(
            ${influxCli} user list --json --name ${escapeShellArg user} 2>/dev/null \
              | ${getExe pkgs.jq} -r ".[0].id"
          ); then
            ${influxCli} user delete --id "$id" &>/dev/null
            echo "Deleted user name="${escapeShellArg user}
          fi
        '')
        + flip concatMapStrings cfg.deleteBuckets (bucket: ''
          if id=$(
            ${influxCli} bucket list --json --org ${escapeShellArg bucket.org} --name ${escapeShellArg bucket.name} 2>/dev/null \
              | ${getExe pkgs.jq} -r ".[0].id"
          ); then
            ${influxCli} bucket delete --id "$id" &>/dev/null
            echo "Deleted bucket org="${escapeShellArg bucket.org}" name="${escapeShellArg bucket.name}
          fi
        '')
        + flip concatMapStrings cfg.deleteOrganizations (org: ''
          if id=$(
            ${influxCli} org list --json --name ${escapeShellArg org} 2>/dev/null \
              | ${getExe pkgs.jq} -r ".[0].id"
          ); then
            ${influxCli} org delete --id "$id" &>/dev/null
            echo "Deleted org name="${escapeShellArg org}
          fi
        '')
        + flip concatMapStrings cfg.ensureOrganizations (org: let
          listArgs = [
            "--name"
            org.name
          ];
          updateArgs = optionals (org.description != null) [
            "--description"
            org.description
          ];
          createArgs = listArgs ++ updateArgs;
        in ''
          if id=$(
            ${influxCli} org list --json ${escapeShellArgs listArgs} 2>/dev/null \
              | ${getExe pkgs.jq} -r ".[0].id"
          ); then
            ${influxCli} org update --id "$id" ${escapeShellArgs updateArgs} &>/dev/null
          else
            ${influxCli} org create ${escapeShellArgs createArgs} &>/dev/null
            echo "Created org name="${escapeShellArg org.name}
          fi
        '')
        + flip concatMapStrings cfg.ensureBuckets (bucket: let
          listArgs = [
            "--org"
            bucket.org
            "--name"
            bucket.name
          ];
          updateArgs =
            [
              "--retention"
              bucket.retention
            ]
            ++ optionals (bucket.description != null) [
              "--description"
              bucket.description
            ];
          createArgs = listArgs ++ updateArgs;
        in ''
          if id=$(
            ${influxCli} bucket list --json ${escapeShellArgs listArgs} 2>/dev/null \
              | ${getExe pkgs.jq} -r ".[0].id"
          ); then
            ${influxCli} bucket update --id "$id" ${escapeShellArgs updateArgs} &>/dev/null
          else
            ${influxCli} bucket create ${escapeShellArgs createArgs} &>/dev/null
            echo "Created bucket org="${escapeShellArg bucket.org}" name="${escapeShellArg bucket.name}
          fi
        '')
        + flip concatMapStrings cfg.ensureUsers (user: let
          listArgs = [
            "--name"
            user.name
          ];
          createArgs =
            listArgs
            ++ [
              "--org"
              user.org
            ];
        in
          ''
            if id=$(
              ${influxCli} user list --json ${escapeShellArgs listArgs} 2>/dev/null \
                | ${getExe pkgs.jq} -r ".[0].id"
            ); then
              true # No updateable args
            else
              ${influxCli} user create ${escapeShellArgs createArgs} &>/dev/null
              echo "Created user name="${escapeShellArg user.name}
            fi
          ''
          + optionalString (user.passwordFile != null) ''
            ${influxCli} user password ${escapeShellArgs listArgs} \
              --password "$(< ${escapeShellArg user.passwordFile})" &>/dev/null
          '')
        + flip concatMapStrings cfg.ensureRemotes (remote: let
          listArgs = [
            "--name"
            remote.name
            "--org"
            remote.org
          ];
          updateArgs =
            [
              "--remote-url"
              remote.remoteUrl
            ]
            ++ optionals (remote.remoteOrgId != null) [
              "--remote-org-id"
              remote.remoteOrgId
            ]
            ++ optionals (remote.description != null) [
              "--description"
              remote.description
            ];
          createArgs = listArgs ++ updateArgs;
        in ''
          if id=$(
            ${influxCli} remote list --json ${escapeShellArgs listArgs} 2>/dev/null \
              | ${getExe pkgs.jq} -r ".[0].id"
          ); then
            ${influxCli} remote update --id "$id" ${escapeShellArgs updateArgs} &>/dev/null \
              --remote-api-token "$(< ${escapeShellArg remote.remoteTokenFile})"
          else
            extraArgs=()
            ${optionalString (remote.remoteOrg != null) ''
            remote_org_id=$(
              ${influxCli} org list --json \
                --host ${escapeShellArg remote.remoteUrl} \
                --token "$(< ${escapeShellArg remote.remoteTokenFile})" \
                --name ${escapeShellArg remote.remoteOrg} 2>/dev/null \
                | ${getExe pkgs.jq} -r ".[0].id"
            )
            extraArgs+=("--remote-org-id" "$remote_org_id")
          ''}
            ${influxCli} remote create ${escapeShellArgs createArgs} &>/dev/null \
              --remote-api-token "$(< ${escapeShellArg remote.remoteTokenFile})" \
              "''${extraArgs[@]}"
            echo "Created remote org="${escapeShellArg remote.org}" name="${escapeShellArg remote.name}
          fi
        '')
        + flip concatMapStrings cfg.ensureReplications (replication: let
          listArgs = [
            "--name"
            replication.name
            "--org"
            replication.org
          ];
          createArgs =
            listArgs
            ++ [
              "--local-bucket"
              replication.localBucket
              "--remote-bucket"
              replication.remoteBucket
            ];
        in ''
          if id=$(
            ${influxCli} replication list --json ${escapeShellArgs listArgs} 2>/dev/null \
              | ${getExe pkgs.jq} -r ".[0].id"
          ); then
            true # No updateable args
          else
            remote_id=$(
              ${influxCli} remote list --json --name ${escapeShellArg replication.remote} 2>/dev/null \
                | ${getExe pkgs.jq} -r ".[0].id"
            )
            ${influxCli} replication create ${escapeShellArgs createArgs} &>/dev/null \
              --remote-id "$remote_id"
            echo "Created replication org="${escapeShellArg replication.org}" name="${escapeShellArg replication.name}
          fi
        '')
        + flip concatMapStrings cfg.ensureApiTokens (apiToken: let
          listArgs = [
            "--user"
            apiToken.user
            "--org"
            apiToken.org
          ];
          createArgs =
            listArgs
            ++ [
              "--description"
              (optionalString (apiToken.description != null) "${apiToken.description} - " + apiToken.id)
            ]
            ++ optional apiToken.operator "--operator"
            ++ optional apiToken.allAccess "--all-access"
            ++ map (x: "--read-${x}") apiToken.readPermissions
            ++ map (x: "--write-${x}") apiToken.writePermissions;
        in ''
          if id=$(
            ${influxCli} apiToken list --json ${escapeShellArgs listArgs} 2>/dev/null \
              | ${getExe pkgs.jq} -r ".[0].id"
          ); then
            true # No updateable args
          else
            declare -A bucketIds
            ${flip concatMapStrings (unique (apiToken.readBuckets ++ apiToken.writeBuckets)) (bucket: ''
            bucketIds[${escapeShellArg bucket}]=$(
              ${influxCli} bucket list --json --org ${escapeShellArg apiToken.org} --name ${escapeShellArg bucket} 2>/dev/null \
                | ${getExe pkgs.jq} -r ".[0].id"
            )
          '')}
            extraArgs=(
              ${flip concatMapStrings apiToken.readBuckets (bucket: ''
            "--read-bucket" "''${bucketIds[${escapeShellArg bucket}]}"
          '')}
              ${flip concatMapStrings apiToken.writeBuckets (bucket: ''
            "--write-bucket" "''${bucketIds[${escapeShellArg bucket}]}"
          '')}
            )
            ${influxCli} auth create ${escapeShellArgs createArgs} &>/dev/null \
              "''${extraArgs[@]}"
            echo "Created api token org="${escapeShellArg apiToken.org}" user="${escapeShellArg apiToken.user}
          fi
        '');
    };
  };
}
