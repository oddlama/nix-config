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
    format-secrets = let
      isAbsolutePath = x: substring 0 1 x == "/";
      masterIdentityArgs = concatMapStrings (x: ''-i "${x}" '') self.secrets.masterIdentities;
      extraEncryptionPubkeys =
        concatMapStrings (
          x:
            if isAbsolutePath x
            then ''-R "${x}" ''
            else ''-r "${x}" ''
        )
        self.secrets.extraEncryptionPubkeys;
      formatSecret = path: ''
        '';
    in
      mkApp (pkgs.writeShellScript "format-secrets" ''
        set -euo pipefail
	      [[ -d .git ]] && [[ -f flake.nix ]] || { echo "[1;31merror:[m Please execute this from the project's root folder (the folder with flake.nix)" >&2; exit 1; }
	      for f in $(find . -type f -name '*.nix.age'); do
	        echo "Formatting $f ..."
	        decrypted=$(${./rage-decrypt.sh} --print-out-path "$f" ${concatStringsSep " " self.secrets.masterIdentities}) \
            || { echo "[1;31merror:[m Failed to decrypt!" >&2; exit 1; }
	        formatted=$(${pkgs.alejandra}/bin/alejandra --quiet < "$decrypted") \
            || { echo "[1;31merror:[m Failed to format $decrypted!" >&2; exit 1; }
	      	${pkgs.rage}/bin/rage -e ${masterIdentityArgs} ${extraEncryptionPubkeys} <<< "$formatted" > "$f" \
            || { echo "[1;31merror:[m Failed to re-encrypt!" >&2; exit 1; }
	      done
      '');
  }
