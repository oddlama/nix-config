{
  lib,
  config,
  nixos-hardware,
  pkgs,
  ...
}: let
  dataDir = "/var/lib/esphome";
in {
  systemd.services.esphome = {
    description = "ESPHome Service";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      ExecStart = "${pkgs.esphome}/bin/esphome dashboard --socket /run/esphome/esphome.sock ${dataDir}";
      User = "esphome";
      Group = "esphome";
      WorkingDirectory = dataDir;
      RuntimeDirectory = "esphome";
      Restart = "on-failure";

      # Hardening
      CapabilityBoundingSet = "";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      DevicePolicy = "closed";
      DeviceAllow = "/dev/serial/by-id/usb-Silicon_Labs_CP2102_USB_to_UART_Bridge_Controller_0001-if00-port0";
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
      ReadWritePaths = dataDir;
      RemoveIPC = true;
      RestrictAddressFamilies = ["AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6"];
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

  users.users.esphome = {
    home = dataDir;
    createHome = true;
    group = "esphome";
    uid = 316;
  };

  users.groups.esphome.gid = 316;

  # TODO esphome.sock permissions pls nginx currently world writable
  services.nginx.upstreams = {
    "esphome" = {
      servers = {"unix:/run/esphome/esphome.sock" = {};};
      extraConfig = ''
        zone esphome 64k;
        keepalive 2;
      '';
    };
  };
  services.nginx.virtualHosts = {
    #"${nodeSecrets.esphome.domain}" = {
    #  forceSSL = true;
    #  enableACME = true;
    "192.168.1.22" = {
      locations."/" = {
        proxyPass = "http://esphome";
        proxyWebsockets = true;
      };
    };
  };
}
