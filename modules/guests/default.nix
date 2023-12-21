{
  config,
  inputs,
  lib,
  pkgs,
  utils,
  ...
} @ attrs: let
  inherit
    (lib)
    attrNames
    attrValues
    attrsToList
    disko
    escapeShellArg
    flip
    groupBy
    listToAttrs
    makeBinPath
    mapAttrs
    mapAttrsToList
    mergeToplevelConfigs
    mkIf
    mkMerge
    mkOption
    net
    types
    ;

  backends = ["microvm" "container"];
  nodeName = config.node.name;
  guestsByBackend =
    lib.genAttrs backends (_: {})
    // mapAttrs (_: listToAttrs) (groupBy (x: x.value.backend) (attrsToList config.guests));

  # List the necessary mount units for the given guest
  fsMountUnitsFor = guestCfg:
    map
    (x: "${utils.escapeSystemdPath x.hostMountpoint}.mount")
    (attrValues guestCfg.zfs);

  # Configuration required on the host for a specific guest
  defineGuest = _guestName: guestCfg: {
    # Add the required datasets to the disko configuration of the machine
    disko.devices.zpool = mkMerge (flip map (attrValues guestCfg.zfs) (zfsCfg: {
      ${zfsCfg.pool}.datasets.${zfsCfg.dataset} =
        disko.zfs.filesystem zfsCfg.hostMountpoint;
    }));

    # Ensure that the zfs dataset exists before it is mounted.
    systemd.services = mkMerge (flip map (attrValues guestCfg.zfs) (zfsCfg: let
      fsMountUnit = "${utils.escapeSystemdPath zfsCfg.hostMountpoint}.mount";
    in {
      "zfs-ensure-${utils.escapeSystemdPath zfsCfg.hostMountpoint}" = {
        wantedBy = [fsMountUnit];
        before = [fsMountUnit];
        after = [
          "zfs-import-${utils.escapeSystemdPath zfsCfg.pool}.service"
          "zfs-mount.target"
        ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = let
          poolDataset = "${zfsCfg.pool}/${zfsCfg.dataset}";
          diskoDataset = config.disko.devices.zpool.${zfsCfg.pool}.datasets.${zfsCfg.dataset};
        in ''
          export PATH=${makeBinPath [pkgs.zfs]}":$PATH"
          if ! zfs list -H -o type ${escapeShellArg poolDataset} &>/dev/null ; then
            ${diskoDataset._create}
          fi
        '';
      };
    }));
  };

  defineMicrovm = guestName: guestCfg: {
    # Ensure that the zfs dataset exists before it is mounted.
    systemd.services."microvm@${guestName}" = {
      requires = fsMountUnitsFor guestCfg;
      after = fsMountUnitsFor guestCfg;
    };

    microvm.vms.${guestName} = import ./microvm.nix guestName guestCfg attrs;
  };

  defineContainer = guestName: guestCfg: {
    # Ensure that the zfs dataset exists before it is mounted.
    systemd.services."container@${guestName}" = {
      requires = fsMountUnitsFor guestCfg;
      after = fsMountUnitsFor guestCfg;
      # Don't use the notify service type. Using exec will always consider containers
      # started immediately and donesn't wait until the container is fully booted.
      # Containers should behave like independent machines, and issues inside the container
      # will unnecessarily lock up the service on the host otherwise.
      # This causes issues on system activation or when containers take longer to start
      # than TimeoutStartSec.
      serviceConfig.Type = lib.mkForce "exec";
    };

    containers.${guestName} = import ./container.nix guestName guestCfg attrs;
  };
in {
  imports = [
    # Add the host module, but only enable if it necessary
    inputs.microvm.nixosModules.host
    # This is opt-out, so we can't put this into the mkIf below
    {
      microvm.host.enable = guestsByBackend.microvm != {};
    }
  ];

  options.node.type = mkOption {
    type = types.enum ["host" "microvm" "container"];
    description = "The type of this machine.";
    default = "host";
  };

  options.containers = mkOption {
    type = types.attrsOf (types.submodule (submod: {
      options.nixosConfiguration = mkOption {
        type = types.unspecified;
        default = null;
        description = "Set this to the result of a `nixosSystem` invocation to use it as the guest system. This will set the `path` option for you.";
      };
      config = mkIf (submod.config.nixosConfiguration != null) {
        path = submod.config.nixosConfiguration.config.system.build.toplevel;
      };
    }));
  };

  options.guests = mkOption {
    default = {};
    description = "Defines the actual vms and handles the necessary base setup for them.";
    type = types.attrsOf (types.submodule (submod: {
      options = {
        nodeName = mkOption {
          type = types.str;
          default = "${nodeName}-${submod.config._module.args.name}";
          description = ''
            The name of the resulting node. By default this will be a compound name
            of the host's name and the vm's name to avoid name clashes. Can be
            overwritten to designate special names to specific vms.
          '';
        };

        backend = mkOption {
          type = types.enum backends;
          description = ''
            Determines how the guest will be hosted. You can currently choose
            between microvm based deployment, or nixos containers.
          '';
        };

        # Options for the microvm backend
        microvm = {
          system = mkOption {
            type = types.str;
            description = "The system that this microvm should use";
          };

          macvtap = mkOption {
            type = types.str;
            description = "The host interface to which the microvm should be attached via macvtap";
          };

          baseMac = mkOption {
            type = types.net.mac;
            description = "The base mac address from which the guest's mac will be derived. Only the second and third byte are used, so for 02:XX:YY:ZZ:ZZ:ZZ, this specifies XX and YY, while Zs are generated automatically. Not used if the mac is set directly.";
            default = "02:01:27:00:00:00";
          };

          mac = mkOption {
            type = types.net.mac;
            description = "The MAC address for the guest's macvtap interface";
            default = let
              base = "02:${lib.substring 3 5 submod.config.microvm.baseMac}:00:00:00";
            in
              (net.mac.assignMacs base 24 [] (attrNames config.guests)).${submod.config._module.args.name};
          };
        };

        # Options for the container backend
        container = {
          macvlan = mkOption {
            type = types.str;
            description = "The host interface to which the container should be attached";
          };
        };

        networking.mainLinkName = mkOption {
          type = types.str;
          description = "The main ethernet link name inside of the guest. For containers, this cannot be named similar to an existing interface on the host.";
          default =
            if submod.config.backend == "microvm"
            then submod.config.microvm.macvtap
            else if submod.config.backend == "container"
            then "mv-${submod.config.container.macvlan}"
            else throw "Invalid backend";
        };

        zfs = mkOption {
          description = "zfs datasets to mount into the guest";
          default = {};
          type = types.attrsOf (types.submodule (zfsSubmod: {
            options = {
              pool = mkOption {
                type = types.str;
                description = "The host's zfs pool on which the dataset resides";
              };

              dataset = mkOption {
                type = types.str;
                example = "safe/guests/mycontainer";
                description = "The host's dataset that should be used for this mountpoint (will automatically be created, including parent datasets)";
              };

              hostMountpoint = mkOption {
                type = types.path;
                default = "/guests/${submod.config._module.args.name}${zfsSubmod.config._module.args.name}";
                example = "/guests/mycontainer/persist";
                description = "The host's mountpoint for the guest's dataset";
              };

              guestMountpoint = mkOption {
                type = types.path;
                default = zfsSubmod.config._module.args.name;
                example = "/persist";
                description = "The mountpoint inside the guest.";
              };
            };
          }));
        };

        autostart = mkOption {
          type = types.bool;
          default = false;
          description = "Whether this VM should be started automatically with the host";
        };

        modules = mkOption {
          type = types.listOf types.unspecified;
          default = [];
          description = "Additional modules to load";
        };
      };
    }));
  };

  config = mkIf (config.guests != {}) (
    mkMerge [
      {
        systemd.tmpfiles.rules = [
          "d /guests 0700 root root -"
        ];
      }
      (mergeToplevelConfigs ["disko" "systemd"] (mapAttrsToList defineGuest config.guests))
      (mergeToplevelConfigs ["containers" "systemd"] (mapAttrsToList defineContainer guestsByBackend.container))
      (mergeToplevelConfigs ["microvm" "systemd"] (mapAttrsToList defineMicrovm guestsByBackend.microvm))
    ]
  );
}
