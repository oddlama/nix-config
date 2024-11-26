{
  inputs,
  self,
  ...
}:
{
  imports = [
    inputs.agenix-rekey.flakeModule
  ];

  flake = {
    # The identities that are used to rekey agenix secrets and to
    # decrypt all repository-wide secrets.
    secretsConfig = {
      masterIdentities = [ ../secrets/yk1-nix-rage.pub ];
      extraEncryptionPubkeys = [ ../secrets/backup.pub ];
    };
  };

  perSystem =
    { config, ... }:
    {
      agenix-rekey.nixosConfigurations = self.nodes;
      devshells.default = {
        commands = [
          {
            inherit (config.agenix-rekey) package;
            help = "Edit, generate and rekey secrets";
          }
        ];
        env = [
          {
            # Always add files to git after agenix rekey and agenix generate.
            name = "AGENIX_REKEY_ADD_TO_GIT";
            value = "true";
          }
        ];
      };
    };
}
