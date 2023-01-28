{
  self,
  nixpkgs,
  ...
}: system:
with nixpkgs.lib; let
  pkgs = self.pkgs.${system};
  toPubkey = pubkey:
    if isPath pubkey
    then readFile pubkey
    else pubkey;

  rekeyCommandsForHost = hostName: hostAttrs: let
    hostPubkeyStr = toPubkey hostAttrs.config.rekey.hostPubkey;
    secretDir = "/tmp/nix-rekey/${builtins.hashString "sha1" hostPubkeyStr}";
    rekeyCommand = secretName: secretAttrs: let
      masterIdentityArgs = concatMapStrings (x: ''-i "${x}" '') hostAttrs.config.rekey.masterIdentityPaths;
      secretOut = "${secretDir}/${secretName}.age";
    in ''
      echo "Rekeying ${secretName} for host ${hostName}"
      ${pkgs.rage}/bin/rage ${masterIdentityArgs} -d ${secretAttrs.file} \
        | ${pkgs.rage}/bin/rage -r "${hostPubkeyStr}" -o "${secretOut}" -e \
        || { \
          echo "[1;31mFailed to rekey secret ${secretName} for ${hostName}![m" ; \
          echo "This is a dummy replacement value. The actual secret could not be rekeyed." \
            | ${pkgs.rage}/bin/rage -r "${hostPubkeyStr}" -o "${secretOut}" -e ; \
        }
    '';
  in ''
    mkdir -p "${secretDir}"
    # Enable selected age plugins for this host
    export PATH="$PATH${concatMapStrings (x: ":${x}/bin") hostAttrs.config.rekey.agePlugins}"
    ${concatStringsSep "\n" (mapAttrsToList rekeyCommand hostAttrs.config.rekey.secrets)}
  '';

  rekeyScript = pkgs.writeShellScript "rekey" ''
    set -euo pipefail
    ${concatStringsSep "\n" (mapAttrsToList rekeyCommandsForHost self.nixosConfigurations)}
    nix run --extra-sandbox-paths /tmp "${../.}#rekey-save-outputs";
  '';

  rekeySaveOutputsScript = let
    copyHostSecrets = hostName: hostAttrs: let
      drv = import ./rekey-output-derivation.nix pkgs hostAttrs.config;
    in ''echo "Stored rekeyed secrets for ${hostAttrs.config.networking.hostName} in ${drv}"'';
  in
    pkgs.writeShellScript "rekey-save-outputs" ''
      set -euo pipefail
      ${concatStringsSep "\n" (mapAttrsToList copyHostSecrets self.nixosConfigurations)}
    '';
in {
  rekey = {
    type = "app";
    program = "${rekeyScript}";
  };
  rekey-save-outputs = {
    type = "app";
    program = "${rekeySaveOutputsScript}";
  };
}
