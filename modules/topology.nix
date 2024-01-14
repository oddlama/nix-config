{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    flip
    filterAttrs
    mapAttrs
    mapAttrs'
    mapAttrsToList
    mkMerge
    mkOption
    nameValuePair
    types
    ;
in {
  options.topology = {
    id = mkOption {
      description = ''
        The attribute name in nixosConfigurations corresponding to this host.
        Please overwrite with a unique identifier if your hostnames are not
        unique or don't reflect the name you use to refer to that node.
      '';
      type = types.str;
    };
    guests = mkOption {
      description = "TODO guests ids (topology.id)";
      type = types.listOf types.str;
      default = [];
    };
    type = mkOption {
      description = "TODO";
      type = types.enum ["normal" "microvm" "nixos-container"];
      default = "normal";
    };
    interfaces = mkOption {
      description = "TODO";
      type = types.attrsOf (types.submodule (submod: {
        options = {
          name = mkOption {
            description = "The name of this interface";
            type = types.str;
            readOnly = true;
            default = submod.config._module.args.name;
          };

          mac = mkOption {
            description = "The MAC address of this interface, if known.";
            type = types.nullOr types.str;
            default = null;
          };

          addresses = mkOption {
            description = "The configured address(es), or a descriptive string (like DHCP).";
            type = types.listOf types.str;
          };
        };
      }));
      default = {};
    };
    disks = mkOption {
      type = types.attrsOf (types.submodule (submod: {
        options = {
          name = mkOption {
            description = "The name of this disk";
            type = types.str;
            readOnly = true;
            default = submod.config._module.args.name;
          };
        };
      }));
      default = {};
    };
  };

  config.topology = mkMerge [
    {
      ################### TODO user config! #################
      id = config.node.name;
      ################### END user config   #################

      guests =
        flip mapAttrsToList (config.microvm.vms or {})
        (_: vmCfg: vmCfg.config.config.topology.id);
      # TODO: container

      disks =
        flip mapAttrs (config.disko.devices.disk or {})
        (_: _: {});
      # TODO: microvm shares
      # TODO: container shares

      interfaces = let
        isNetwork = netDef: (netDef.matchConfig != {}) && (netDef.address != [] || netDef.DHCP != null);
        macsByName = mapAttrs' (flip nameValuePair) (config.networking.renameInterfacesByMac or {});
        netNameFor = netName: netDef:
          netDef.matchConfig.Name
          or (
            if netDef ? matchConfig.MACAddress && macsByName ? ${netDef.matchConfig.MACAddress}
            then macsByName.${netDef.matchConfig.MACAddress}
            else lib.trace "Could not derive network name for systemd network ${netName} on host ${config.node.name}, using unit name as fallback." netName
          );
        netMACFor = netDef: netDef.matchConfig.MACAddress or null;
        networks = filterAttrs (_: isNetwork) (config.systemd.network.networks or {});
      in
        flip mapAttrs' networks (netName: netDef:
          nameValuePair (netNameFor netName netDef) {
            mac = netMACFor netDef;
            addresses =
              if netDef.address != []
              then netDef.address
              else ["DHCP"];
          });

      # TODO: for each nftable zone show open ports
    }
  ];
}
