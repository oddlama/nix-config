{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    literalExpression
    maintainers
    mkEnableOption
    mkIf
    mkOption
    mdDoc
    types
    ;

  cfg = config.services.esphome;

  stateDir = "/var/lib/esphome";

  esphomeParams =
    if cfg.enableUnixSocket
    then "--socket /run/esphome/esphome.sock"
    else "--address ${cfg.address} --port ${toString cfg.port}";
in {
  meta.maintainers = with maintainers; [oddlama];

  options.services.esphome = {
    enable = mkEnableOption (mdDoc "esphome");

    package = mkOption {
      type = types.package;
      default = pkgs.esphome;
      defaultText = literalExpression "pkgs.esphome";
      description = mdDoc "The package to use for the esphome command.";
    };

    enableUnixSocket = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Listen on a unix socket `/run/esphome/esphome.sock` instead of the TCP port.";
    };

    address = mkOption {
      type = types.str;
      default = "localhost";
      description = mdDoc "esphome address";
    };

    port = mkOption {
      type = types.port;
      default = 6052;
      description = mdDoc "esphome port";
    };

    openFirewall = mkOption {
      default = false;
      type = types.bool;
      description = mdDoc "Whether to open the firewall for the specified port.";
    };

    allowedDevices = mkOption {
      default = [];
      example = [
        {
          node = "/dev/serial/by-id/usb-Silicon_Labs_CP2102_USB_to_UART_Bridge_Controller_0001-if00-port0";
          modifier = "rw";
        }
      ];
      description = lib.mdDoc ''
        A list of device nodes to which {command}`esphome` has access to.
        Beware that permissions are not added dynamically when a device
        is plugged in while the service is already running.
      '';
      type = types.listOf (types.submodule {
        options = {
          node = mkOption {
            example = "/dev/ttyUSB*";
            type = types.str;
            description = lib.mdDoc "Path to device node";
          };
          modifier = mkOption {
            example = "rw";
            type = types.str;
            description = lib.mdDoc ''
              Device node access modifier. Takes a combination
              `r` (read), `w` (write), and `m` (mknod). See the
              `systemd.resource-control(5)` man page for more
              information.
            '';
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = mkIf (cfg.openFirewall && !cfg.enableUnixSocket) [cfg.port];

    systemd.services.esphome = {
      description = "ESPHome dashboard";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      path = [cfg.package];
      environment.PLATFORMIO_CORE_DIR = "${stateDir}/.platformio";

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/esphome dashboard ${esphomeParams} ${stateDir}";
        DynamicUser = true;
        User = "esphome";
        Group = "esphome";
        WorkingDirectory = stateDir;
        StateDirectory = "esphome";
        StateDirectoryMode = "0750";
        Restart = "on-failure";
        RuntimeDirectory = mkIf cfg.enableUnixSocket "esphome";
        RuntimeDirectoryMode = "0750";

        # Hardening
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        DevicePolicy = "closed";
        DeviceAllow = map (d: "${d.node} ${d.modifier}") cfg.allowedDevices;
        SupplementaryGroups = ["dialout"];
        NoNewPrivileges = true;
        PrivateUsers = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProcSubset = "pid";
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_UNIX"
        ];
        RestrictNamespaces = false; # Required by platformio for chroot
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "@mount" # Required by platformio for chroot
        ];
        UMask = "0077";
      };
    };
  };
}
