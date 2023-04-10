{
  self,
  pkgs,
  ...
}: let
  inherit
    (pkgs.lib)
    concatStringsSep
    filterAttrs
    hasInfix
    mapAttrsToList
    ;
  mapAttrsToLines = f: attrs: concatStringsSep "\n" (mapAttrsToList f attrs);
  filterMapAttrsToLines = filter: f: attrs: concatStringsSep "\n" (mapAttrsToList f (filterAttrs filter attrs));
  renderNode = nodeName: node: let
    renderNic = nicName: nic: ''
      nic_${nicName}: ${
        if hasInfix "wlan" nicName
        then "📶"
        else "🖧"
      } ${self.hosts.${nodeName}.physicalConnections.${nicName}} {
        shape: sql_table
        MAC: ${nic.matchConfig.MACAddress}
      }
    '';
  in ''
    ${nodeName}: {
      ${filterMapAttrsToLines (_: v: v.matchConfig ? MACAddress) renderNic node.config.systemd.network.networks}
    }
  '';
  # TODO vms
  graph = ''
    ${mapAttrsToLines renderNode self.colmenaNodes}
  '';
in
  pkgs.writeShellScript "draw-graph" ''
    set -euo pipefail
    echo "${graph}"
  ''
