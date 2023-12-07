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
    disko
    escapeShellArg
    makeBinPath
    mapAttrsToList
    mdDoc
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

  cfg = config.meta.microvms;
  nodeName = config.node.name;
  inherit (cfg) vms;

  # Configuration for each microvm
  microvmConfig = vmName: vmCfg: {
    # Add the required datasets to the disko configuration of the machine
    disko.devices.zpool = mkIf vmCfg.zfs.enable {
      ${vmCfg.zfs.pool}.datasets.${vmCfg.zfs.dataset} =
        disko.zfs.filesystem vmCfg.zfs.mountpoint;
    };

    # Ensure that the zfs dataset exists before it is mounted.
    systemd.services = let
      fsMountUnit = "${utils.escapeSystemdPath vmCfg.zfs.mountpoint}.mount";
    in
      mkIf vmCfg.zfs.enable {
        # Ensure that the zfs dataset exists before it is mounted.
        "zfs-ensure-${utils.escapeSystemdPath vmCfg.zfs.mountpoint}" = {
          wantedBy = [fsMountUnit];
          before = [fsMountUnit];
          after = [
            "zfs-import-${utils.escapeSystemdPath vmCfg.zfs.pool}.service"
            "zfs-mount.target"
          ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = let
            poolDataset = "${vmCfg.zfs.pool}/${vmCfg.zfs.dataset}";
            diskoDataset = config.disko.devices.zpool.${vmCfg.zfs.pool}.datasets.${vmCfg.zfs.dataset};
          in ''
            export PATH=${makeBinPath [pkgs.zfs]}":$PATH"
            if ! zfs list -H -o type ${escapeShellArg poolDataset} &>/dev/null ; then
              ${diskoDataset._create}
            fi
          '';
        };

        # Ensure that the zfs dataset has the correct permissions when mounted
        "zfs-chown-${utils.escapeSystemdPath vmCfg.zfs.mountpoint}" = {
          after = [fsMountUnit];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = ''
            chmod 700 ${escapeShellArg vmCfg.zfs.mountpoint}
          '';
        };

        "microvm@${vmName}" = {
          requires = [fsMountUnit "zfs-chown-${utils.escapeSystemdPath vmCfg.zfs.mountpoint}.service"];
          after = [fsMountUnit "zfs-chown-${utils.escapeSystemdPath vmCfg.zfs.mountpoint}.service"];
        };
      };

    microvm.vms.${vmName} = let
      mac = (net.mac.assignMacs "02:01:27:00:00:00" 24 [] (attrNames vms)).${vmName};
    in {
      # Allow children microvms to know which node is their parent
      specialArgs = {
        parentNode = config;
        parentNodeName = nodeName;
        inherit (inputs.self) nodes;
        inherit (inputs.self.pkgs.${vmCfg.system}) lib;
        inherit inputs;
        inherit minimal;
      };
      pkgs = inputs.self.pkgs.${vmCfg.system};
      inherit (vmCfg) autostart;
      config = {
        imports = cfg.commonImports ++ vmCfg.modules;
        node.name = vmCfg.nodeName;

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
              id = "vm-${vmName}";
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
                source = "/state/vms/${vmName}";
                mountPoint = "/state";
                tag = "state";
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

        networking.renameInterfacesByMac.${vmCfg.networking.mainLinkName} = mac;

        systemd.network.networks = {
          "10-${vmCfg.networking.mainLinkName}" = {
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
          zones.untrusted.interfaces = [vmCfg.networking.mainLinkName];
        };
      };
    };
  };
in {
  imports = [
    # Add the host module, but only enable if it necessary
    inputs.microvm.nixosModules.host
    # This is opt-out, so we can't put this into the mkIf below
    {microvm.host.enable = vms != {};}
  ];

  options.meta.microvms = {
    commonImports = mkOption {
      type = types.listOf types.unspecified;
      default = [];
      description = mdDoc "Modules to import on all microvms.";
    };

    networking = {
      baseMac = mkOption {
        type = types.net.mac;
        description = mdDoc ''
          This MAC address will be used as a base address to derive all MicroVM MAC addresses from.
          A good practise is to use the physical address of the macvtap interface.
        '';
      };

      macvtapInterface = mkOption {
        type = types.str;
        description = mdDoc "The macvtap interface to which MicroVMs should be attached";
      };

      wireguard = {
        cidrv4 = mkOption {
          type = types.net.cidrv4;
          description = mdDoc "The ipv4 network address range to use for internal vm traffic.";
          default = "172.31.0.0/24";
        };

        cidrv6 = mkOption {
          type = types.net.cidrv6;
          description = mdDoc "The ipv6 network address range to use for internal vm traffic.";
          default = "fd00:172:31::/120";
        };

        port = mkOption {
          default = 51829;
          type = types.port;
          description = mdDoc "The port to listen on.";
        };

        openFirewallRules = mkOption {
          default = [];
          type = types.listOf types.str;
          description = mdDoc "The {option}`port` will be opened for all of the given rules in the nftable-firewall.";
        };
      };
    };

    vms = mkOption {
      default = {};
      description = "Defines the actual vms and handles the necessary base setup for them.";
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          nodeName = mkOption {
            type = types.str;
            default = "${nodeName}-${name}";
            description = mdDoc ''
              The name of the resulting node. By default this will be a compound name
              of the host's name and the vm's name to avoid name clashes. Can be
              overwritten to designate special names to specific vms.
            '';
          };

          networking = {
            mainLinkName = mkOption {
              type = types.str;
              default = "wan";
              description = mdDoc "The main ethernet link name inside of the VM";
            };
          };

          zfs = {
            enable = mkEnableOption (mdDoc "persistent data on separate zfs dataset");

            pool = mkOption {
              type = types.str;
              description = mdDoc "The host's zfs pool on which the dataset resides";
            };

            dataset = mkOption {
              type = types.str;
              default = "safe/vms/${name}";
              description = mdDoc "The host's dataset that should be used for this vm's state (will automatically be created, parent dataset must exist)";
            };

            mountpoint = mkOption {
              type = types.str;
              default = "/vms/${name}";
              description = mdDoc "The host's mountpoint for the vm's dataset (will be shared via virtiofs as /persist in the vm)";
            };
          };

          autostart = mkOption {
            type = types.bool;
            default = false;
            description = mdDoc "Whether this VM should be started automatically with the host";
          };

          system = mkOption {
            type = types.str;
            description = mdDoc "The system that this microvm should use";
          };

          modules = mkOption {
            type = types.listOf types.unspecified;
            default = [];
            description = mdDoc "Additional modules to load";
          };
        };
      }));
    };
  };

  config = mkIf (vms != {}) (mergeToplevelConfigs ["disko" "microvm" "systemd"] (mapAttrsToList microvmConfig vms));
}
