{
  self,
  pkgs,
  ...
}: let
  inherit
    (pkgs.lib)
    escapeShellArg
    concatStringsSep
    mapAttrsToList
    ;
  mapAttrsToLines = f: attrs: concatStringsSep "\n" (mapAttrsToList f attrs);
  generateHostKey = node: ''
    if [[ ! -f ${escapeShellArg node.config.rekey.secrets.initrd_host_ed25519_key.file} ]]; then
      echo TODOOOOO
      exit 1
      ssh-keygen -t ed25519 -N "" -f /tmp/1
      TODO
    fi
  '';
in
  pkgs.writeShellScript "generate-initrd-keys" ''
    set -euo pipefail
    ${mapAttrsToLines generateHostKey self.nodes}
  ''
