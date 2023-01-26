{
  lib,
  options,
  config,
  pkgs,
  ...
}:
let
  rekeySecrets = ageLikeSecrets: let
    #srcs = map (x: x.file) age; [./secrets/backup.txt ./secrets/recipients.txt];
    secretFiles = [ ../../secrets/backup.txt ../../secrets/recipients.txt ];
	masterIdentityPaths = [ ../../secrets/yk1-nix-rage.txt ../../secrets/backup.txt ];
	masterIdentities = builtins.concatStringsSep " " (map (x: "-i ${x}") masterIdentityPaths);
	rekeyCommand = secret: ''
	  ${pkgs.rage}/bin/rage -d ${masterIdentities} ${secret} \
	    | ${pkgs.rage}/bin/rage -e -i ${rekey.key} -o "$out/${builtins.baseNameOf secret}"
	  '';
    rekeyedSecrets = pkgs.stdenv.mkDerivation {
      name = "host-secrets";
	  dontUnpack = true;
	  dontConfigure = true;
	  dontBuild = true;
      installPhase = ''
	    set -euo pipefail
	    mkdir "$out"
        # Temporarily
		${builtins.concatStringsSep "\n" (map rekeyCommand ageLikeSecrets)}
      '';
    };
  in
    rekeyedSecrets;
in {
  config.environment.systemPackages = with pkgs; [rage];
  # TODO age.identityPaths = [ (generateKeyForHost config.network.hostName) ];

  # Produce a rekeyed age secret for each of the secrets defined in rekey secrets
  options.rekey.secrets = options.age.secrets;
  config.age.secrets = rekeySecrets config.rekey.secrets;
}

#rekey.secrets.my_secret.file = ./secrets/somekey.age;
#pwdfile = rekey.secrets.mysecret.path;
