{
  config,
  extraLib,
  inputs,
  lib,
  microvm,
  nodeName,
  nodePath,
  pkgs,
  ...
}: let
  inherit
    (lib)
    attrNames
    concatStringsSep
    escapeShellArg
    filterAttrs
    foldl'
    mapAttrsToList
    mdDoc
    mkDefault
    mkEnableOption
    mkForce
    mkIf
    mkMerge
    mkOption
    optional
    recursiveUpdate
    types
    ;

  cfg = config.extra.microvms;

  # Configuration for each microvm
  microvmConfig = vmName: vmCfg: {
    # Add the required datasets to the disko configuration of the machine
    disko.devices.zpool = mkIf (vmCfg.zfs.enable && vmCfg.zfs.disko) {
      ${vmCfg.zfs.pool}.datasets."${vmCfg.zfs.dataset}" =
        extraLib.disko.zfs.filesystem "${vmCfg.zfs.mountpoint}";
    };

    # TODO not cool, this might change or require more creation options.
    # TODO better to only add disko and a mount point requirement.
    # TODO the user can do the rest if required.
    # TODO needed for boot false

    # When installing a microvm, make sure that its persitent zfs dataset exists
    systemd.services."install-microvm-${vmName}".preStart = let
      poolDataset = "${vmCfg.zfs.pool}/${vmCfg.zfs.dataset}";
    in
      mkIf vmCfg.zfs.enable ''
        if ! ${pkgs.zfs}/bin/zfs list -H -o type ${escapeShellArg poolDataset} &>/dev/null ; then
          ${pkgs.zfs}/bin/zfs create -o canmount=on -o mountpoint=${escapeShellArg vmCfg.zfs.mountpoint} ${escapeShellArg poolDataset}
        fi
      '';

    microvm.autostart = mkIf vmCfg.autostart [vmName];
    microvm.vms.${vmName} = let
      node =
        (import ../nix/generate-node.nix inputs)
        "${nodeName}-microvm-${vmName}" {
          inherit (vmCfg) system;
          config = nodePath + "/microvms/${vmName}";
        };
    in {
      inherit (node) pkgs specialArgs;
      config = {
        imports = [microvm.microvm] ++ node.imports;

        microvm = {
          hypervisor = mkDefault "cloud-hypervisor";

          # MACVTAP bridge to the host's network
          interfaces = [
            {
              type = "macvtap";
              id = "vm-${vmName}";
              macvtap = {
                link = vmCfg.macvtap;
                mode = "bridge";
              };
              inherit (vmCfg) mac;
            }
          ];

          shares =
            [
              # Share the nix-store of the host
              {
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
                tag = "ro-store";
                proto = "virtiofs";
              }
            ]
            # Mount persistent data from the host
            ++ optional vmCfg.zfs.enable {
              source = vmCfg.zfs.mountpoint;
              mountPoint = "/persist";
              tag = "persist";
              proto = "virtiofs";
            };
        };

        # FIXME this should be changed in microvm.nix to mkDefault instead of mkForce here
        fileSystems."/persist".neededForBoot = mkForce true;

        # Add a writable store overlay, but since this is always ephemeral
        # disable any store optimization from nix.
        microvm.writableStoreOverlay = "/nix/.rw-store";
        nix = {
          settings.auto-optimise-store = mkForce false;
          optimise.automatic = mkForce false;
          gc.automatic = mkForce false;
        };

        extra.networking.renameInterfacesByMac.${vmCfg.linkName} = vmCfg.mac;

        systemd.network.networks = {
          "10-${vmCfg.linkName}" = {
            matchConfig.Name = vmCfg.linkName;
            DHCP = "yes";
            networkConfig = {
              IPv6PrivacyExtensions = "yes";
              IPv6AcceptRA = true;
            };
            linkConfig.RequiredForOnline = "routable";
          };
        };

        # TODO change once microvms are compatible with stage-1 systemd
        boot.initrd.systemd.enable = mkForce false;
      };
    };
  };
in {
  imports = [
    # Add the host module, but only enable if it necessary
    microvm.host
    # This is opt-out, so we can't put this into the mkIf below
    {microvm.host.enable = cfg != {};}
    # This module requires declarativeUpdates and restartIfChanged.
    {
      microvm = mkIf (cfg != {}) {
        declarativeUpdates = true;
        restartIfChanged = true;
      };
    }
  ];

  options.extra.microvms = mkOption {
    default = {};
    description = "Handles the necessary base setup for MicroVMs.";
    type = types.attrsOf (types.submodule {
      options = {
        zfs = {
          enable = mkEnableOption (mdDoc "Enable persistent data on separate zfs dataset");

          pool = mkOption {
            type = types.str;
            description = mdDoc "The host's zfs pool on which the dataset resides";
          };

          dataset = mkOption {
            type = types.str;
            description = mdDoc "The host's dataset that should be used for this vm's state (will automatically be created, parent dataset must exist)";
          };

          mountpoint = mkOption {
            type = types.str;
            description = mdDoc "The host's mountpoint for the vm's dataset (will be shared via virtofs as /persist in the vm)";
          };

          disko = mkOption {
            type = types.bool;
            default = true;
            description = mdDoc "Add this dataset to the host's disko configuration";
          };
        };

        autostart = mkOption {
          type = types.bool;
          default = false;
          description = mdDoc "Whether this VM should be started automatically with the host";
        };

        linkName = mkOption {
          type = types.str;
          default = "wan";
          description = mdDoc "The main ethernet link name inside of the VM";
        };

        mac = mkOption {
          type = config.lib.net.types.mac;
          description = mdDoc "The MAC address to assign to this VM";
        };

        macvtap = mkOption {
          type = types.str;
          description = mdDoc "The macvtap interface to attach to";
        };

        system = mkOption {
          type = types.str;
          description = mdDoc "The system that this microvm should use";
        };
      };
    });
  };

  config = mkIf (cfg != {}) (
    {
      assertions = let
        duplicateMacs = extraLib.duplicates (mapAttrsToList (_: vmCfg: vmCfg.mac) cfg);
      in [
        {
          assertion = duplicateMacs == [];
          message = "Duplicate MicroVM MAC addresses: ${concatStringsSep ", " duplicateMacs}";
        }
      ];
    }
    // lib.genAttrs ["disko" "microvm" "systemd"]
    (attr:
      mkMerge (map
        (c: c.${attr})
        (mapAttrsToList microvmConfig cfg)))
  );
}
