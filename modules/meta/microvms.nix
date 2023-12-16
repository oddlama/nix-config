{
  config,
  inputs,
  lib,
  pkgs,
  utils,
  minimal,
  ...
}: let
  inherit
    (lib)
    attrNames
    attrValues
    any
    disko
    escapeShellArg
    makeBinPath
    mapAttrsToList
    mergeToplevelConfigs
    mkDefault
    mkEnableOption
    mkForce
    mkIf
    mkOption
    net
    optional
    types
    ;

  cfg = config.guests;
  nodeName = config.node.name;
  inherit (cfg) guests;

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
      };

    microvm.vms.${guestName} = let
      mac = (net.mac.assignMacs "02:01:27:00:00:00" 24 [] (attrNames guests)).${guestName};
    in
      mkIf (guestCfg.backend == "microvm") {
        # Allow children microvms to know which node is their parent
        specialArgs = {
          parentNode = config;
          inherit (inputs.self) nodes;
          inherit (inputs.self.pkgs.${guestCfg.microvm.system}) lib;
          inherit inputs;
          inherit minimal;
        };
        pkgs = inputs.self.pkgs.${guestCfg.microvm.system};
        inherit (guestCfg) autostart;
        config = {
          imports = guestCfg.modules;
          node.name = guestCfg.nodeName;
          node.isGuest = true;

          # TODO needed because of https://github.com/NixOS/nixpkgs/issues/102137
          environment.noXlibs = mkForce false;
          lib.microvm.mac = mac;

          microvm = {
            hypervisor = mkDefault "qemu";

            # Give them some juice by default
            mem = mkDefault (2 * 1024);

            # MACVTAP bridge to the host's network
            interfaces = [
              {
                type = "macvtap";
                id = "vm-${guestName}";
                inherit mac;
                macvtap = {
                  link = cfg.networking.macvtapInterface;
                  mode = "bridge";
                };
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
                {
                  source = "/state/guests/${guestName}";
                  mountPoint = "/state";
                  tag = "state";
                  proto = "virtiofs";
                }
              ]
              # Mount persistent data from the host
              ++ optional guestCfg.zfs.enable {
                source = guestCfg.zfs.mountpoint;
                mountPoint = "/persist";
                tag = "persist";
                proto = "virtiofs";
              };
          };

          # FIXME this should be changed in microvm.nix to mkDefault in oder to not require mkForce here
          fileSystems."/state".neededForBoot = mkForce true;
          fileSystems."/persist".neededForBoot = mkForce true;

          # Add a writable store overlay, but since this is always ephemeral
          # disable any store optimization from nix.
          microvm.writableStoreOverlay = "/nix/.rw-store";
          nix = {
            settings.auto-optimise-store = mkForce false;
            optimise.automatic = mkForce false;
            gc.automatic = mkForce false;
          };

          networking.renameInterfacesByMac.${guestCfg.networking.mainLinkName} = mac;

          systemd.network.networks = {
            "10-${guestCfg.networking.mainLinkName}" = {
              matchConfig.MACAddress = mac;
              DHCP = "yes";
              dhcpV4Config.UseDNS = false;
              dhcpV6Config.UseDNS = false;
              ipv6AcceptRAConfig.UseDNS = false;
              networkConfig = {
                IPv6PrivacyExtensions = "yes";
                MulticastDNS = true;
                IPv6AcceptRA = true;
              };
              linkConfig.RequiredForOnline = "routable";
            };
          };

          networking.nftables.firewall = {
            zones.untrusted.interfaces = [guestCfg.networking.mainLinkName];
          };
        };
      };

    containers.${guestName} =
      mkIf (guestCfg.backend == "microvm") {
      };
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
        (attrValues guests);
    }
  ];

  options.node.isGuest = mkOption {
    type = types.bool;
    description = "Whether this machine is a guest on another machine.";
    default = false;
  };

  # networking = {
  #   baseMac = mkOption {
  #     type = types.net.mac;
  #     description = ''
  #       This MAC address will be used as a base address to derive all MicroVM MAC addresses from.
  #       A good practise is to use the physical address of the macvtap interface.
  #     '';
  #   };
  #
  #   macvtapInterface = mkOption {
  #     type = types.str;
  #     description = "The macvtap interface to which MicroVMs should be attached";
  #   };
  # };

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

  config = mkIf (guests != {}) (mergeToplevelConfigs ["disko" "microvm" "systemd"] (mapAttrsToList defineGuest guests));
}
