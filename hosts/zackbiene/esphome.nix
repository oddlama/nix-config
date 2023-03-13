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
      DevicePolicy = "closed";
      LockPersonality = true;
      MemoryDenyWriteExecute = false;
      NoNewPrivileges = true;
      PrivateDevices = true;
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
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service @pkey"
        "~@privileged @resources"
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
}
