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
    attrValues
    any
    disko
    escapeShellArg
    makeBinPath
    mapAttrsToList
    mergeToplevelConfigs
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  nodeName = config.node.name;

  # Configuration required on the host for a specific guest
  defineGuest = guestName: guestCfg: {
    # Add the required datasets to the disko configuration of the machine
    disko.devices.zpool = mkIf guestCfg.zfs.enable {
      ${guestCfg.zfs.pool}.datasets.${guestCfg.zfs.dataset} =
        disko.zfs.filesystem guestCfg.zfs.mountpoint;
    };

    # Ensure that the zfs dataset exists before it is mounted.
    systemd.services = let
      fsMountUnit = "${utils.escapeSystemdPath guestCfg.zfs.mountpoint}.mount";
    in
      mkIf guestCfg.zfs.enable {
        # Ensure that the zfs dataset exists before it is mounted.
        "zfs-ensure-${utils.escapeSystemdPath guestCfg.zfs.mountpoint}" = {
          wantedBy = [fsMountUnit];
          before = [fsMountUnit];
          after = [
            "zfs-import-${utils.escapeSystemdPath guestCfg.zfs.pool}.service"
            "zfs-mount.target"
          ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = let
            poolDataset = "${guestCfg.zfs.pool}/${guestCfg.zfs.dataset}";
            diskoDataset = config.disko.devices.zpool.${guestCfg.zfs.pool}.datasets.${guestCfg.zfs.dataset};
          in ''
            export PATH=${makeBinPath [pkgs.zfs]}":$PATH"
            if ! zfs list -H -o type ${escapeShellArg poolDataset} &>/dev/null ; then
              ${diskoDataset._create}
            fi
          '';
        };

        # Ensure that the zfs dataset has the correct permissions when mounted
        "zfs-chown-${utils.escapeSystemdPath guestCfg.zfs.mountpoint}" = {
          after = [fsMountUnit];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = ''
            chmod 700 ${escapeShellArg guestCfg.zfs.mountpoint}
          '';
        };

        "microvm@${guestName}" = mkIf (guestCfg.backend == "microvm") {
          requires = [fsMountUnit "zfs-chown-${utils.escapeSystemdPath guestCfg.zfs.mountpoint}.service"];
          after = [fsMountUnit "zfs-chown-${utils.escapeSystemdPath guestCfg.zfs.mountpoint}.service"];
        };

        "container@${guestName}" = mkIf (guestCfg.backend == "container") {
          requires = [fsMountUnit "zfs-chown-${utils.escapeSystemdPath guestCfg.zfs.mountpoint}.service"];
          after = [fsMountUnit "zfs-chown-${utils.escapeSystemdPath guestCfg.zfs.mountpoint}.service"];
        };
      };

    microvm.vms.${guestName} =
      mkIf (guestCfg.backend == "microvm") (import ./microvm.nix guestName guestCfg attrs);

    containers.${guestName} =
      mkIf (guestCfg.backend == "container") (import ./container.nix guestName guestCfg attrs);
  };
in {
  imports = [
    # Add the host module, but only enable if it necessary
    inputs.microvm.nixosModules.host
    # This is opt-out, so we can't put this into the mkIf below
    {
      microvm.host.enable =
        any
        (guestCfg: guestCfg.backend == "microvm")
        (attrValues config.guests);
    }
  ];

  options.node.type = mkOption {
    type = types.enum ["host" "microvm" "container"];
    description = "The type of this machine.";
    default = "host";
  };

  options.guests = mkOption {
    default = {};
    description = "Defines the actual vms and handles the necessary base setup for them.";
    type = types.attrsOf (types.submodule ({name, ...}: {
      options = {
        nodeName = mkOption {
          type = types.str;
          default = "${nodeName}-${name}";
          description = ''
            The name of the resulting node. By default this will be a compound name
            of the host's name and the vm's name to avoid name clashes. Can be
            overwritten to designate special names to specific vms.
          '';
        };

        backend = mkOption {
          type = types.enum ["microvm" "container"];
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

          macvtapInterface = mkOption {
            type = types.str;
            description = "The host macvtap interface to which the microvm should be attached";
          };
        };

        # Options for the container backend
        container = {
          macvlan = mkOption {
            type = types.str;
            description = "The host interface to which the container should be attached";
          };
        };

        networking = {
          mainLinkName = mkOption {
            type = types.str;
            default = "wan";
            description = "The main ethernet link name inside of the VM";
          };
        };

        zfs = {
          enable = mkEnableOption "persistent data on separate zfs dataset";

          pool = mkOption {
            type = types.str;
            description = "The host's zfs pool on which the dataset resides";
          };

          dataset = mkOption {
            type = types.str;
            default = "safe/guests/${name}";
            description = "The host's dataset that should be used for this vm's state (will automatically be created, parent dataset must exist)";
          };

          mountpoint = mkOption {
            type = types.str;
            default = "/guests/${name}";
            description = "The host's mountpoint for the vm's dataset (will be shared via virtiofs as /persist in the vm)";
          };
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

  config =
    mkIf (config.guests != {})
    (mergeToplevelConfigs ["containers" "disko" "microvm" "systemd"] (mapAttrsToList defineGuest config.guests));
}
