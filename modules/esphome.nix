{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    mdDoc
    types
    ;

  cfg = config.services.esphome;

  name = "esphome";

  stateDir = "/var/lib/${name}";
in {
  options.services.esphome = {
    enable = mkEnableOption (mdDoc "esphome");

    package = mkOption {
      type = types.package;
      default = pkgs.esphome;
      defaultText = literalExpression "pkgs.esphome";
      description = mdDoc "The package to use for the esphome command.";
    };

    enableUnixSocket = mkEnableOption (lib.mdDoc ''
      Expose a unix socket under /run/esphome/esphome.sock instead of using a TCP socket.
    '');

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

      serviceConfig = {
        ExecStart = let
          extraParams =
            if cfg.enableUnixSocket
            then "--socket /run/${name}/esphome.sock"
            else "--address ${cfg.address} --port ${toString cfg.port}";
        in "${cfg.package}/bin/esphome dashboard ${extraParams} ${stateDir}";
        DynamicUser = true;
        WorkingDirectory = stateDir;
        StateDirectory = name;
        StateDirectoryMode = "0750";
        Restart = "on-failure";
        RuntimeDirectory = mkIf cfg.enableUnixSocket name;
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
