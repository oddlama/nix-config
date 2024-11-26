{
  config,
  lib,
  nixosConfig,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.userSecretsName = mkOption {
    default = "user-${config._module.args.name}";
    type = types.str;
    description = "The secrets attribute name that should be made available as userSecrets";
  };

  options.userSecrets = mkOption {
    readOnly = true;
    default = nixosConfig.repo.secrets.${config.userSecretsName};
    type = types.unspecified;
    description = "Conveniently exposes the secrets for this user, if any.";
  };
}
