{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    assertMsg
    attrNames
    literalExpression
    mapAttrs
    mdDoc
    mkIf
    mkOption
    types
    ;

  # If the given expression is a bare set, it will be wrapped in a function,
  # so that the imported file can always be applied to the inputs, similar to
  # how modules can be functions or sets.
  constSet = x:
    if builtins.isAttrs x
    then (_: x)
    else x;

  # Try to access the extra builtin we loaded via nix-plugins.
  # Throw an error if that doesn't exist.
  rageImportEncrypted = assert assertMsg (builtins ? extraBuiltins.rageImportEncrypted) "The extra builtin 'rageImportEncrypted' is not available, so repo.secrets cannot be decrypted. Did you forget to use `defineNixExtraBuiltins` or use the appropriate ad-hoc command line arguments?";
    builtins.extraBuiltins.rageImportEncrypted;

  # This "imports" an encrypted .nix.age file by evaluating the decrypted content.
  importEncrypted = path:
    constSet (
      if builtins.pathExists path
      then rageImportEncrypted inputs.self.secretsConfig.masterIdentities path
      else {}
    );

  cfg = config.repo;
in {
  options.repo = {
    defineNixExtraBuiltins = mkOption {
      default = false;
      type = types.bool;
      description = mdDoc ''
        Add nix-plugins and the correct extra-builtin-files definition to this host's
        nix configuration, so that it can be used to decrypt the secrets in this repository.
      '';
    };

    secretFiles = mkOption {
      default = {};
      type = types.attrsOf types.path;
      example = literalExpression "{ local = ./secrets.nix.age; }";
      description = mdDoc ''
        This file manages the origin for this machine's repository-secrets. Anything that is
        technically not a secret in the classical sense (i.e. that it has to be protected
        after it has been deployed), but something you want to keep secret from the public;
        Anything that you wouldn't want people to see on GitHub, but that can live unencrypted
        on your own devices. Consider it a more ergonomic nix alternative to using git-crypt.

        All of these secrets may (and probably will be) put into the world-readable nix-store
        on the build and target hosts. You'll most likely want to store personally identifiable
        information here, such as:
          - MAC Addreses
          - Static IP addresses
          - Your full name (when configuring your users)
          - Your postal address (when configuring e.g. home-assistant)
          - ...

        Each path given here must be an age-encrypted .nix file. For each attribute `<name>`,
        the corresponding file will be decrypted, imported and exposed as {option}`repo.secrets.<name>`.
      '';
    };

    secrets = mkOption {
      readOnly = true;
      default = mapAttrs (_: x: importEncrypted x inputs) cfg.secretFiles;
      type = types.unspecified;
      description = "Exposes the loaded repo secrets. This option is read-only.";
    };
  };

  config = {
    # Make sure not to reference the extra-builtins file directly but
    # at least via its parent folder so it can access relative files.
    nix.extraOptions = mkIf cfg.defineNixExtraBuiltins ''
      plugin-files = ${pkgs.nix-plugins}/lib/nix/plugins
      extra-builtins-file = ${inputs.self.outPath}/nix/extra-builtins.nix
    '';
  };
}
