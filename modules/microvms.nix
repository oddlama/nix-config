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
    optionalAttrs
    recursiveUpdate
    types
    ;

  cfg = config.extra.microvms;
  inherit (config.extra.microvms) vms;
  inherit (config.lib) net;

  # Configuration for each microvm
  microvmConfig = vmName: vmCfg: {
    # Add the required datasets to the disko configuration of the machine
    disko.devices.zpool = mkIf vmCfg.zfs.enable {
      ${vmCfg.zfs.pool}.datasets."${vmCfg.zfs.dataset}" =
        extraLib.disko.zfs.filesystem vmCfg.zfs.mountpoint;
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
          ${config.disko.devices.zpool.${vmCfg.zfs.pool}.datasets.${vmCfg.zfs.dataset}._create {zpool = vmCfg.zfs.pool;}}
        fi
      '';

    microvm.vms.${vmName} = let
      node =
        (import ../nix/generate-node.nix inputs)
        "${nodeName}-microvm-${vmName}" {
          inherit (vmCfg) system;
          config = nodePath + "/microvms/${vmName}";
        };
      mac = net.mac.addPrivate vmCfg.id cfg.networking.baseMac;
    in {
      # Allow children microvms to know which node is their parent
      specialArgs =
        {
          parentNode = config;
          parentNodeName = nodeName;
        }
        // node.specialArgs;
      inherit (node) pkgs;
      inherit (vmCfg) autostart;
      config = {
        imports = [microvm.microvm] ++ node.imports;

        microvm = {
          hypervisor = mkDefault "cloud-hypervisor";

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

        extra.networking.renameInterfacesByMac.${vmCfg.networking.mainLinkName} = mac;

        systemd.network.networks."10-${vmCfg.networking.mainLinkName}" =
          {
            manual = {};
            dhcp = {
              matchConfig.Name = vmCfg.networking.mainLinkName;
              DHCP = "yes";
              networkConfig = {
                IPv6PrivacyExtensions = "yes";
                IPv6AcceptRA = true;
              };
              linkConfig.RequiredForOnline = "routable";
            };
            static = {
              matchConfig.Name = vmCfg.networking.mainLinkName;
              address = [
                "${vmCfg.networking.static.ipv4}/${toString (net.cidr.length cfg.networking.static.baseCidrv4)}"
                "${vmCfg.networking.static.ipv6}/${toString (net.cidr.length cfg.networking.static.baseCidrv6)}"
              ];
              gateway = [
                cfg.networking.host
              ];
              networkConfig = {
                IPv6PrivacyExtensions = "yes";
                IPv6AcceptRA = true;
              };
              linkConfig.RequiredForOnline = "routable";
            };
          }
          .${vmCfg.networking.mode};

        # TODO change once microvms are compatible with stage-1 systemd
        boot.initrd.systemd.enable = mkForce false;

        # Create a firewall zone for the bridged traffic and secure vm traffic
        # TODO mkForce nftables
        networking.nftables.firewall = {
          zones = mkForce {
            "${vmCfg.networking.mainLinkName}".interfaces = [vmCfg.networking.mainLinkName];
            local-vms.interfaces = ["local-vms"];
          };

          rules = mkForce {
            "${vmCfg.networking.mainLinkName}-to-local" = {
              from = [vmCfg.networking.mainLinkName];
              to = ["local"];
            };

            local-vms-to-local = {
              from = ["local-vms"];
              to = ["local"];
            };
          };
        };

        extra.wireguard."${nodeName}-local-vms" = {
          # We have a resolvable hostname / static ip, so all peers can directly communicate with us
          server = optionalAttrs (cfg.networking.host != null) {
            inherit (vmCfg.networking) host;
            inherit (cfg.networking.wireguard) port;
            openFirewallRules = ["${vmCfg.networking.mainLinkName}-to-local"];
          };
          # If We don't have such guarantees, so we must use a client-server architecture.
          client = optionalAttrs (cfg.networking.host == null) {
            via = nodeName;
            keepalive = false;
          };
          linkName = "local-vms";
          ipv4 = net.cidr.host vmCfg.id cfg.networking.wireguard.cidrv4;
          ipv6 = net.cidr.host vmCfg.id cfg.networking.wireguard.cidrv6;
        };
      };
    };
  };
in {
  imports = [
    # Add the host module, but only enable if it necessary
    microvm.host
    # This is opt-out, so we can't put this into the mkIf below
    {microvm.host.enable = vms != {};}
  ];

  options.extra.microvms = {
    networking = {
      baseMac = mkOption {
        type = net.types.mac;
        description = mdDoc ''
          This MAC address will be used as a base address to derive all MicroVM MAC addresses from.
          A good practise is to use the physical address of the macvtap interface.
        '';
      };

      static = {
        baseCidrv4 = mkOption {
          type = net.types.cidrv4;
          description = mdDoc ''
            If a MicroVM is using static networking, and it hasn't defined a specific
            address to use, its ipv4 address will be derived from this base address and its `id`.
          '';
        };

        baseCidrv6 = mkOption {
          type = net.types.cidrv6;
          description = mdDoc ''
            If a MicroVM is using static networking, and it hasn't defined a specific
            address to use, its ipv6 address will be derived from this base address and its `id`.
          '';
        };
      };

      host = mkOption {
        type = types.str;
        default = net.cidr.host 1 cfg.networking.static.baseCidrv4;
        description = mdDoc ''
          The ip or resolveable hostname under which this machine can be reached from other
          participants of the bridged macvtap network. Defaults to the first host
          in the given static base ipv4 address range.
        '';
      };

      macvtapInterface = mkOption {
        type = types.str;
        description = mdDoc "The macvtap interface to which MicroVMs should be attached";
      };

      wireguard = {
        cidrv4 = mkOption {
          type = net.types.cidrv4;
          description = mdDoc "The ipv4 network address range to use for internal vm traffic.";
          default = "172.31.0.0/24";
        };

        cidrv6 = mkOption {
          type = net.types.cidrv6;
          description = mdDoc "The ipv6 network address range to use for internal vm traffic.";
          default = "fddd::/64";
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
      type = types.attrsOf (types.submodule ({config, ...}: {
        options = {
          id = mkOption {
            type =
              types.addCheck types.int (x: x > 1)
              // {
                name = "positiveInt1";
                description = "positive integer greater than 1";
              };
            description = mdDoc ''
              A unique id for this VM. It will be used to derive a MAC address from the host's
              base MAC, and may be used as a stable id by your MicroVM config if necessary.

              Ids don't need to be contiguous. It is recommended to use small numbers here to not
              overflow any offset calculations. Consider that this is used for example to determine a
              static ip-address by means of (baseIp + vm.id) for a wireguard network. That's also
              why id 1 is reserved for the host. While this is usually checked to be in-range,
              it might still be a good idea to assign greater ids with care.
            '';
          };

          networking = {
            mode = mkOption {
              type = types.enum ["dhcp" "static" "manual"];
              default = "static";
              description = "Determines how the main macvtap bridged network interface is configured this MicroVM.";
            };

            mainLinkName = mkOption {
              type = types.str;
              default = "wan";
              description = mdDoc "The main ethernet link name inside of the VM";
            };

            static = {
              ipv4 = mkOption {
                type = net.types.ipv4-in cfg.networking.static.baseCidrv4;
                default = net.cidr.host config.id cfg.networking.static.baseCidrv4;
                description = mdDoc ''
                  The static ipv4 for this MicroVM. Only used if mode is static.
                  Defaults to the id-th host in the configured network range.
                '';
              };

              ipv6 = mkOption {
                type = net.types.ipv6-in cfg.networking.static.baseCidrv6;
                default = net.cidr.host config.id cfg.networking.static.baseCidrv6;
                description = mdDoc ''
                  The static ipv6 for this MicroVM. Only used if mode is static.
                  Defaults to the id-th host in the configured network range.
                '';
              };
            };

            host = mkOption {
              type = types.nullOr types.str;
              default =
                if config.networking.mode == "static"
                then config.networking.static.ipv4
                else null;
              description = mdDoc ''
                The host as which this VM can be reached from other participants of the bridged macvtap network.
                If this is null, the wireguard connection will use a client-server architecture with the host as the server.
                Otherwise, all clients will communicate directly, meaning the host cannot listen to traffic.

                This can either be a resolvable hostname or an IP address. Defaults to the static ipv4 if given, else null.
              '';
            };
          };

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
        };
      }));
    };
  };

  config = mkIf (vms != {}) (
    {
      assertions = let
        duplicateIds = extraLib.duplicates (mapAttrsToList (_: vmCfg: toString vmCfg.id) vms);
      in [
        {
          assertion = duplicateIds == [];
          message = "Duplicate MicroVM ids: ${concatStringsSep ", " duplicateIds}";
        }
      ];

      # Define a local wireguard server to communicate with vms securely
      extra.wireguard."${nodeName}-local-vms" = {
        server = {
          inherit (cfg.networking) host;
          inherit (cfg.networking.wireguard) openFirewallRules port;
        };
        linkName = "local-vms";
        ipv4 = net.cidr.host 1 cfg.networking.wireguard.cidrv4;
        ipv6 = net.cidr.host 1 cfg.networking.wireguard.cidrv6;
      };

      # Create a firewall zone for the secure vm traffic
      # TODO mkForce nftables
      networking.nftables.firewall = {
        zones = mkForce {
          local-vms.interfaces = ["local-vms"];
        };

        rules = mkForce {
          local-vms-to-local = {
            from = ["local-vms"];
            to = ["local"];
          };
        };
      };
    }
    // extraLib.mergeToplevelConfigs ["disko" "microvm" "systemd"] (mapAttrsToList microvmConfig vms)
  );
}
