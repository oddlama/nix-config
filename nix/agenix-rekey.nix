{inputs, ...}: {
  flake = {config, ...}: {
    # The identities that are used to rekey agenix secrets and to
    # decrypt all repository-wide secrets.
    secretsConfig = {
      masterIdentities = [../secrets/yk1-nix-rage.pub];
      extraEncryptionPubkeys = [../secrets/backup.pub];
    };

    agenix-rekey = inputs.agenix-rekey.configure {
      userFlake = inputs.self;
      inherit (config) nodes pkgs;
    };
  };

  perSystem.devshells.default.env = [
    {
      # Always add files to git after agenix rekey and agenix generate.
      name = "AGENIX_REKEY_ADD_TO_GIT";
      value = "true";
    }
  ];
}
