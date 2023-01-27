{
  lib,
  options,
  config,
  pkgs,
  ...
}:
with lib; {
  config.environment.systemPackages = with pkgs; [rage];
  config.age = {
    secrets = let
      rekeyedSecrets = lazyDerivation {
        derivation = pkgs.stdenv.mkDerivation rec {
          pname = "host-secrets";
          version = "1.0.0";
          description = "Rekeyed secrets for this host.";

          allSecrets = mapAttrsToList (_: value: value.file) config.rekey.secrets;
          hostPubkeyStr =
            if isPath config.rekey.hostPubkey
            then readFile config.rekey.hostPubkey
            else config.rekey.hostPubkey;

          dontMakeSourcesWritable = true;
          dontUnpack = true;
          dontConfigure = true;
          dontBuild = true;

          installPhase = let
            masterIdentityArgs = concatMapStrings (x: ''-i "${x}" '') config.rekey.masterIdentityPaths;
            rekeyCommand = secret: ''
              echo "Rekeying ${secret}" >&2
                    ${pkgs.rage}/bin/rage ${masterIdentityArgs} -d ${secret}
                      | ${pkgs.rage}/bin/rage -r "${hostPubkeyStr}" -o "$out/${baseNameOf secret}" -e
            '';
          in ''
            set -euo pipefail
            mkdir "$out"

            # Enable selected age plugins
            export PATH="$PATH${concatMapStrings (x: ":${x}/bin") config.rekey.agePlugins}"

            ${concatStringsSep "\n" (map rekeyCommand allSecrets)}
          '';
        };
      };
      rekeyedSecretPath = secret: "${rekeyedSecrets}/${baseNameOf secret}";
    in
      # Produce a rekeyed age secret for each of the secrets defined in our secrets
      mapAttrs (_: secret:
        mapAttrs (name: value:
          if name == "file"
          then rekeyedSecretPath value
          else value)
        secret)
      config.rekey.secrets;

    identityPaths = mkForce config.rekey.agePubkey;
  };
  config.assertions = mkIf (config.rekey.secrets != {}) [
    {
      assertion = pathExists config.rekey.hostPubkey;
      message = "The public key required to rekey secrets for this host doesn't exist. If this is the first deploy, use a mock key until you know the real one.";
    }
    {
      assertion = config.rekey.masterIdentityPaths != [];
      message = "rekey.masterIdentityPaths must be set.";
    }
  ];
  config.warnings = let
    hasGoodSuffix = x: strings.hasSuffix ".age" x || strings.hasSuffix ".pub" x;
  in
    mkIf (!all hasGoodSuffix config.rekey.masterIdentityPaths) [
      ''
        It seems like at least one of your rekey.masterIdentityPaths contains an
        unencrypted age identity. These files will be copied to the nix store, so
        make sure they don't contain any secret information!

        To silence this warning, encrypt your keys and name them *.pub or *.age.
      ''
    ];

  options = {
    rekey.secrets = options.age.secrets;
    rekey.hostPubkey = mkOption {
      type = types.either types.path types.str;
      description = ''
        The age public key to use as a recipient when rekeying.
        This either has to be the path to an age public key file,
        or the public key itself in string form.

        Make sure to NEVER use a private key here, as it will end
        up in the public nix store!
      '';
      #example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEyH9Vx7WJZWW+6tnDsF7JuflcxgjhAQHoCWVrjLXQ2U my-host";
      #example = "age159tavn5rcfnq30zge2jfq4yx60uksz8udndp0g3njzhrns67ca5qq3n0tj";
      example = /etc/ssh/ssh_host_ed25519_key.pub;
    };
    rekey.hostPrivkey = mkOption {
      # Str to prevent privkeys from entering the nix store
      type = types.str;
      description = ''
        The age identity (private key) that should be used to decrypt the secrets on the target machine.
        This corresponds to age.identityPaths and must match the pubkey set in rekey.hostPubkey.
      '';
      example = head (map (e: e.path) (filter (e: e.type == "ed25519") config.services.openssh.hostKeys));
    };
    rekey.masterIdentityPaths = mkOption {
      type = types.listOf types.path;
      description = ''
        The age identity used to decrypt the secrets stored in the repository, so they can be rekeyed for a specific host.
        This identity will be stored in the nix store, so be sure to use a split-identity (like a yubikey identity, which is public),
        or an encrypted age identity. You can encrypt an age identity using `rage -p -o privkey.age privkey` to protect it in your store.

        All identities given here will be passed to age, which will select one of them for decryption.
      '';
      default = [];
      example = [./secrets/my-yubikey-identity.txt];
    };
    rekey.agePlugins = mkOption {
      type = types.listOf types.package;
      default = [];
      description = ''
        A list of plugins that should be available to rage while rekeying.
        They will be added to the PATH before rage is invoked.
      '';
      example = [pkgs.age-plugin-yubikey];
    };
  };
}
#rekey.secrets.my_secret.file = ./secrets/somekey.age;
#pwdfile = rekey.secrets.mysecret.path;

