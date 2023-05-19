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
      mac = config.lib.net.mac.addPrivate vmCfg.id cfg.networking.baseMac;
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
                link = cfg.macvtapInterface;
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

        extra.networking.renameInterfacesByMac.${vmCfg.linkName} = mac;

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

        # Create a firewall zone for the bridged traffic and secure vm traffic
        networking.nftables.firewall = {
          zones = lib.mkForce {
            "${vmCfg.linkName}".interfaces = [vmCfg.linkName];
            "local-vms".interfaces = ["wg-local-vms"];
          };

          rules = lib.mkForce {
            "${vmCfg.linkName}-to-local" = {
              from = [vmCfg.linkName];
              to = ["local"];
            };

            local-vms-to-local = {
              from = ["wg-local-vms"];
              to = ["local"];
            };
          };
        };

        extra.wireguard."local-vms" = {
          # We have a resolvable hostname / static ip, so all peers can directly communicate with us
          server = optionalAttrs (cfg.networking.host != null) {
            inherit (vmCfg) host;
            port = 51829;
            openFirewallInRules = ["${vmCfg.linkName}-to-local"];
          };
          # We have no static hostname, so we must use a client-server architecture.
          client = optionalAttrs (cfg.networking.host == null) {
            via = nodeName;
            keepalive = false;
          };
          # TODO check error: addresses = ["10.22.22.2/30"];
          # TODO switch wg module to explicit v4 and v6
          addresses = [
            "${config.lib.net.cidr.host vmCfg.id cfg.networking.wireguard.netv4}/32"
            "${config.lib.net.cidr.host vmCfg.id cfg.networking.wireguard.netv6}/128"
          ];
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
        type = config.lib.net.types.mac;
        description = mdDoc ''
          This MAC address will be used as a base address to derive all MicroVM MAC addresses from.
          A good practise is to use the physical address of the macvtap interface.
        '';
      };

      host = mkOption {
        type = types.str;
        description = mdDoc ''
          The host as which this machine can be reached from other participants of the bridged macvtap network.
          This can either be a resolvable hostname or an IP address.
        '';
      };

      macvtapInterface = mkOption {
        type = types.str;
        description = mdDoc "The macvtap interface to which MicroVMs should be attached";
      };

      wireguard = {
        netv4 = mkOption {
          type = config.lib.net.types.cidrv4;
          description = mdDoc "The ipv4 network address range to use for internal vm traffic.";
          default = "172.31.0.0/24";
        };

        netv6 = mkOption {
          type = config.lib.net.types.cidrv6;
          description = mdDoc "The ipv6 network address range to use for internal vm traffic.";
          default = "fddd::/64";
        };
      };
      # TODO check plus no overflow
    };

    vms = mkOption {
      default = {};
      description = "Defines the actual vms and handles the necessary base setup for them.";
      type = types.attrsOf (types.submodule {
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

          # TODO allow configuring static ipv4 and ipv6 instead of dhcp?
          # maybe create networking. namespace and have options = dhcpwithRA and static.

          linkName = mkOption {
            type = types.str;
            default = "wan";
            description = mdDoc "The main ethernet link name inside of the VM";
          };

          host = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = mdDoc ''
              The host as which this VM can be reached from other participants of the bridged macvtap network.
              If this is unset, the wireguard connection will use a client-server architecture with the host as the server.
              Otherwise, all clients will communicate directly, meaning the host cannot listen to traffic.

              This can either be a resolvable hostname or an IP address.
            '';
          };

          system = mkOption {
            type = types.str;
            description = mdDoc "The system that this microvm should use";
          };
        };
      });
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
      extra.wireguard."local-vms" = {
        server = {
          inherit (cfg.networking) host;
          port = 51829;
          openFirewallInRules = ["lan-to-local"];
        };
        addresses = [
          (config.lib.net.cidr.hostCidr 1 cfg.networking.wireguard.netv4)
          (config.lib.net.cidr.hostCidr 1 cfg.networking.wireguard.netv6)
        ];
      };
    }
    // extraLib.mergeToplevelConfigs ["disko" "microvm" "systemd"] (mapAttrsToList microvmConfig vms)
  );
}
