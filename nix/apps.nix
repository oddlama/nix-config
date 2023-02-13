{self, ...}: system: let
  mkApp = drv: {
    type = "app";
    program = "${drv}";
  };
  pkgs = self.pkgs.${system};
  mapAttrsToLines = f: attrs: pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList f attrs);
  filterMapAttrsToLines = filter: f: attrs: pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList f (pkgs.lib.filterAttrs filter attrs));
in
  with pkgs.lib; {
    draw-graph = let
      renderNode = nodeName: node: let
        renderNic = nicName: nic: ''
          nic_${nicName}: ${
            if hasInfix "wlan" nicName
            then "📶"
            else "🖧"
          } ${self.hosts.${nodeName}.physical_connections.${nicName}} {
            shape: sql_table
            MAC: ${nic.matchConfig.MACAddress}
          }
        '';
      in ''
        ${nodeName}: {
          ${filterMapAttrsToLines (_: v: v.matchConfig ? MACAddress) renderNic node.config.systemd.network.networks}
        }
      '';
      graph = ''
        ${mapAttrsToLines renderNode self.nodes}
      '';
    in
      mkApp (pkgs.writeShellScript "draw-graph" ''
        set -euo pipefail
        echo "${graph}"
      '');
    generate-initrd-keys = let
      generateHostKey = node: ''
        if [[ ! -f ${node.config.rekey.secrets.initrd_host_ed25519_key.file} ]]; then
          ssh-keygen -t ed25519 -N "" -f /tmp/1
          TODO
        fi
      '';
    in
      mkApp (pkgs.writeShellScript "generate-initrd-keys" ''
        set -euo pipefail
        ${mapAttrsToLines generateHostKey self.nodes}
      '');
  }
