{
  config,
  lib,
  nodes,
  ...
}: let
  inherit
    (lib)
    attrNames
    concatMap
    getAttrFromPath
    mkMerge
    mkOption
    optionals
    types
    ;

  nodeName = config.node.name;
in {
  options.d2diag.text = mkOption {
    # TODO readonly, _text
    description = "TODO";
    type = types.lines;
  };

  options.d2diag.services = mkOption {
    description = "TODO";
    type = types.attrsOf (types.submodule {
      options = {
      };
    });
  };

  config = {
    d2diag.text =
      ''
        ${nodeName}: ${nodeName} {
          disks: Disks {
            shape: sql_table
            ${lib.concatLines (map (x: "${x}: 8TB") (lib.attrNames config.disko.devices.disk))}
          }
          net: Interfaces {
            shape: sql_table
            ${lib.concatLines (lib.mapAttrsToList (n: v: ''${n}: ${v.mac}'') (config.repo.secrets.local.networking.interfaces or {lan.mac = "?";}))}
          }
      ''
      + (lib.optionalString (config.guests != {}) ''
        guests: {
          ${
          lib.concatLines (
            lib.flip lib.mapAttrsToList config.guests (
              guestName: guestDef:
                (
                  if guestDef.backend == "microvm"
                  then config.microvm.vms.${guestName}.config
                  else config.containers.${guestName}.nixosConfiguration
                )
                .config
                .d2diag
                .text
            )
          )
        }
        }

        ${
          lib.concatLines (
            lib.flip lib.mapAttrsToList config.guests (
              guestName: guestDef: "net.lan -> guests.${(
                  if guestDef.backend == "microvm"
                  then config.microvm.vms.${guestName}.config
                  else config.containers.${guestName}.nixosConfiguration
                )
                .config
                .node
                .name}.net.lan"
            )
          )
        }
      '')
      + ''
        }
      '';
  };
}
