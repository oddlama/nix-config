{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    boolToString
    concatMapAttrs
    flip
    getExe
    mkEnableOption
    mkOption
    mkPackageOption
    types
    ;
in
{
  options = {
    services.firezone.gateways = mkOption {
      description = ''
        A set of gateway clients to deploy on this machine. Each gateway can
        connect to exactly one firezone server.
      '';
      default = { };
      type = types.attrsOf (
        types.submodule (gatewaysSubmod: {
          options = {
            package = mkPackageOption pkgs "firezone-gateway" { };

            name = mkOption {
              type = types.str;
              default = gatewaysSubmod.config._module.args.name;
              description = "The name of this gateway as shown in firezone";
            };

            user = mkOption {
              type = types.strMatching "^[a-zA-Z0-9_-]{1,32}$";
              default = "firezone-gw-${gatewaysSubmod.config._module.args.name}";
              description = "The DynamicUser name under which the gateway will run. Cannot exceed 32 characters.";
            };

            interface = mkOption {
              type = types.strMatching "^[a-zA-Z0-9_-]{1,15}$";
              default = "tun-${gatewaysSubmod.config._module.args.name}";
              description = "The name of the TUN interface which will be created by this gateway";
            };

            apiUrl = mkOption {
              type = types.str;
              example = "wss://firezone.example.com/api";
              description = ''
                The URL of your firezone server's API. This should be the same
                as your server's setting for {option}`services.firezone.server.settings.api.externalUrl`,
                but with `wss://` instead of `https://`.
              '';
            };

            tokenFile = mkOption {
              type = types.path;
              example = "/run/secrets/firezone-gateway-token";
              description = ''
                A file containing the firezone gateway token. Do not use a nix-store path here
                as it will make the token publicly readable!

                This file will be passed via systemd credentials, it should only be accessible
                by the root user.
              '';
            };

            logLevel = mkOption {
              type = types.str;
              default = "info";
              description = ''
                The log level for the firezone application. See
                [RUST_LOG](https://docs.rs/env_logger/latest/env_logger/#enabling-logging)
                for the format.
              '';
            };

            enableTelemetry = mkEnableOption "telemetry";
          };
        })
      );
    };
  };

  config = {
    systemd.services = flip concatMapAttrs config.services.firezone.gateways (
      gatewayName: gatewayCfg: {
        "firezone-gateway-${gatewayName}" = {
          description = "Gateway service for the Firezone zero-trust access platform";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];

          path = [ pkgs.util-linux ];
          script = ''
            # If FIREZONE_ID is not given by the user, use a persisted (or newly generated) uuid.
            if [[ -z "''${FIREZONE_ID:-}" ]]; then
              if [[ ! -e gateway_id ]]; then
                uuidgen -r > gateway_id
              fi
              export FIREZONE_ID=$(< gateway_id)
            fi

            export FIREZONE_TOKEN=$(< "$CREDENTIALS_DIRECTORY/firezone-token")
            exec ${getExe gatewayCfg.package}
          '';

          environment = {
            FIREZONE_API_URL = gatewayCfg.apiUrl;
            FIREZONE_NAME = gatewayCfg.name;
            FIREZONE_NO_TELEMETRY = boolToString gatewayCfg.enableTelemetry;
            FIREZONE_TUN_INTERFACE = gatewayCfg.interface;
            RUST_LOG = gatewayCfg.logLevel;
          };

          serviceConfig = {
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
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

            Type = "exec";
            DynamicUser = true;
            User = gatewayCfg.user;
            LoadCredential = [ "firezone-token:${gatewayCfg.tokenFile}" ];

            DeviceAllow = "/dev/net/tun";
            AmbientCapabilities = [ "CAP_NET_ADMIN" ];
            CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];

            StateDirectory = "firezone-gateways/${gatewayName}";
            WorkingDirectory = "/var/lib/firezone-gateways/${gatewayName}";
          };
        };
      }
    );
  };

  meta.maintainers = with lib.maintainers; [
    oddlama
    patrickdag
  ];
}
