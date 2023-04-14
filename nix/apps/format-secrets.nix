{
  self,
  pkgs,
  nixpkgs,
  ...
}: let
  inherit (nixpkgs.lib) concatStringsSep;
  inherit (extraLib) rageEncryptArgs;
in
  pkgs.writeShellScript "format-secrets" ''
    set -euo pipefail
    [[ -d .git ]] && [[ -f flake.nix ]] || { echo "[1;31merror:[m Please execute this from the project's root folder (the folder with flake.nix)" >&2; exit 1; }
    for f in $(find . -type f -name '*.nix.age'); do
      echo "Formatting $f ..."
      decrypted=$(${../rage-decrypt-and-cache.sh} --print-out-path "$f" ${concatStringsSep " " self.secrets.masterIdentities}) \
          || { echo "[1;31merror:[m Failed to decrypt!" >&2; exit 1; }
      formatted=$(${pkgs.alejandra}/bin/alejandra --quiet < "$decrypted") \
          || { echo "[1;31merror:[m Failed to format $decrypted!" >&2; exit 1; }
      ${pkgs.rage}/bin/rage -e ${rageEncryptArgs} <<< "$formatted" > "$f" \
          || { echo "[1;31merror:[m Failed to re-encrypt!" >&2; exit 1; }
    done
  ''
