{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit
    (lib)
    getExe
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    types
    ;

  cfg = config.services.actual;
  configFile = formatType.generate "config.json" cfg.settings;
  dataDir = "/var/lib/actual";

  formatType = pkgs.formats.json {};
in {
  options.services.actual = {
    enable = mkEnableOption "actual, a privacy focused app for managing your finances";
    package = mkPackageOption pkgs "actual-server" {};

    user = mkOption {
      type = types.str;
      default = "actual";
      description = ''
        User to run actual as.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise the sysadmin is responsible for
        ensuring the user exists.
        :::
      '';
    };

    group = mkOption {
      type = types.str;
      default = "actual";
      description = ''
        Group under which to run.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise the sysadmin is responsible for
        ensuring the user exists.
        :::
      '';
    };

    openFirewall = mkOption {
      default = false;
      type = types.bool;
      description = "Whether to open the firewall for the specified port.";
    };

    settings = mkOption {
      default = {};
      type = types.submodule {
        freeformType = formatType.type;

        options = {
          hostname = mkOption {
            type = types.str;
            description = "The address to listen on";
            default = "::";
          };

          port = mkOption {
            type = types.port;
            description = "The port to listen on";
            default = 3000;
          };
        };

        config = {
          serverFiles = "${dataDir}/server-files";
          userFiles = "${dataDir}/user-files";
          inherit dataDir;
        };
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.settings.port];

    users.groups = mkIf (cfg.group == "actual") {
      ${cfg.group} = {};
    };

    users.users = mkIf (cfg.user == "actual") {
      ${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group;
        home = dataDir;
      };
    };

    systemd.services.actual = {
      description = "Actual server, a local-first personal finance app";
      after = ["network.target"];
      environment.ACTUAL_CONFIG_PATH = configFile;
      serviceConfig = {
        ExecStart = getExe cfg.package;
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = "actual";
        WorkingDirectory = dataDir;
        LimitNOFILE = "1048576";
        PrivateTmp = true;
        PrivateDevices = true;
        StateDirectoryMode = "0700";
        Restart = "always";

        # Hardening
        CapabilityBoundingSet = "";
        LockPersonality = true;
        #MemoryDenyWriteExecute = true; # Leads to coredump because V8 does JIT
        PrivateUsers = true;
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
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "@pkey"
        ];
        UMask = "0077";
      };
      wantedBy = ["multi-user.target"];
    };
  };
}
