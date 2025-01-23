{
  pkgs,
  lib,
  ...
}:
let
  interfaces = [
    "me-services"
    "me-devices"
    "me-iot"
    "wan"
  ];
  interfacesRegex = "(${lib.concatStringsSep "|" (interfaces ++ [ "me-home" ])})";
  cfg = {
    interfaces = interfacesRegex;
    rules =
      [
        {
          from = interfacesRegex;
          to = "me-home";
          allow_answers = ".*";
        }
      ]
      ++ lib.forEach interfaces (to: {
        from = "me-home";
        inherit to;
        allow_questions = ".*";
      });
  };
in
{
  systemd.services.mdns-repeater = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment.RUST_LOG = "info";

    serviceConfig = {
      Restart = "on-failure";
      ExecStart = "${lib.getExe pkgs.mdns-repeater} --config ${pkgs.writeText "config.json" (builtins.toJSON cfg)}";

      # Hardening
      DynamicUser = true;
      CapabilityBoundingSet = "";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateUsers = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateMounts = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      RemoveIPC = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
      UMask = "0027";
    };
  };
}
