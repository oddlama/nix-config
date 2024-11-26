{
  config,
  inputs,
  lib,
  ...
}:
{
  # Define local repo secrets
  repo.secretFiles =
    let
      local = config.node.secretsDir + "/local.nix.age";
    in
    lib.optionalAttrs (lib.pathExists local) { inherit local; };

  # Setup secret rekeying parameters
  age.rekey = {
    inherit (inputs.self.secretsConfig)
      masterIdentities
      extraEncryptionPubkeys
      ;

    hostPubkey = config.node.secretsDir + "/host.pub";
    storageMode = "local";
    generatedSecretsDir = inputs.self.outPath + "/secrets/generated/${config.node.name}";
    localStorageDir = inputs.self.outPath + "/secrets/rekeyed/${config.node.name}";
  };

  age.generators.basic-auth =
    {
      pkgs,
      lib,
      decrypt,
      deps,
      ...
    }:
    lib.flip lib.concatMapStrings deps (
      {
        name,
        host,
        file,
      }:
      ''
        echo " -> Aggregating [32m"${lib.escapeShellArg host}":[m[33m"${lib.escapeShellArg name}"[m" >&2
        ${decrypt} ${lib.escapeShellArg file} \
          | ${pkgs.apacheHttpd}/bin/htpasswd -niBC 12 ${lib.escapeShellArg host}"+"${lib.escapeShellArg name} \
          || die "Failure while aggregating basic auth hashes"
      ''
    );

  age.generators.argon2id =
    {
      pkgs,
      lib,
      decrypt,
      deps,
      ...
    }:
    let
      dep = builtins.head deps;
    in
    ''
      echo " -> Deriving argon2id hash from [32m"${lib.escapeShellArg dep.host}":[m[33m"${lib.escapeShellArg dep.name}"[m" >&2
      ${decrypt} ${lib.escapeShellArg dep.file} \
        | tr -d '\n' \
        | ${pkgs.libargon2}/bin/argon2 "$(${pkgs.openssl}/bin/openssl rand -base64 16)" -id -e \
        || die "Failure while generating argon2id hash"
    '';

  # Just before switching, remove the agenix directory if it exists.
  # This can happen when a secret is used in the initrd because it will
  # then be copied to the initramfs under the same path. This materializes
  # /run/agenix as a directory which will cause issues when the actual system tries
  # to create a link called /run/agenix. Agenix should probably fail in this case,
  # but doesn't and instead puts the generation link into the existing directory.
  # TODO See https://github.com/ryantm/agenix/pull/187.
  system.activationScripts = lib.mkIf (config.age.secrets != { }) {
    removeAgenixLink.text = "[[ ! -L /run/agenix ]] && [[ -d /run/agenix ]] && rm -rf /run/agenix";
    agenixNewGeneration.deps = [ "removeAgenixLink" ];
  };
}
