{
  inputs,
  lib,
  nodePath,
  ...
}: {
  # Define local repo secrets
  repo.secretFiles = let
    local = nodePath + "/secrets/local.nix.age";
  in
    {
      global = ../../secrets/global.nix.age;
    }
    // lib.optionalAttrs (nodePath != null && lib.pathExists local) {inherit local;};

  # Setup secret rekeying parameters
  age.rekey = {
    inherit
      (inputs.self.secretsConfig)
      masterIdentities
      extraEncryptionPubkeys
      ;

    # This is technically impure, but intended. We need to rekey on the
    # current system due to yubikey availability.
    forceRekeyOnSystem = builtins.extraBuiltins.unsafeCurrentSystem;
    hostPubkey = let
      pubkeyPath =
        if nodePath == null
        then null
        else nodePath + "/secrets/host.pub";
    in
      lib.mkIf (pubkeyPath != null && lib.pathExists pubkeyPath) pubkeyPath;
  };

  age.generators.dhparams.script = {pkgs, ...}: "${pkgs.openssl}/bin/openssl dhparam 4096";
  age.generators.basic-auth.script = {
    pkgs,
    lib,
    decrypt,
    deps,
    ...
  }:
    lib.flip lib.concatMapStrings deps ({
      name,
      host,
      file,
    }: ''
      echo " -> Aggregating [32m"${lib.escapeShellArg host}":[m[33m"${lib.escapeShellArg name}"[m" >&2
      ${decrypt} ${lib.escapeShellArg file} \
        | ${pkgs.apacheHttpd}/bin/htpasswd -niBC 12 ${lib.escapeShellArg host}"+"${lib.escapeShellArg name} \
        || die "Failure while aggregating basic auth hashes"
    '');

  # Just before switching, remove the agenix directory if it exists.
  # This can happen when a secret is used in the initrd because it will
  # then be copied to the initramfs under the same path. This materializes
  # /run/agenix as a directory which will cause issues when the actual system tries
  # to create a link called /run/agenix. Agenix should probably fail in this case,
  # but doesn't and instead puts the generation link into the existing directory.
  # TODO See https://github.com/ryantm/agenix/pull/187.
  system.activationScripts.removeAgenixLink.text = "[[ ! -L /run/agenix ]] && [[ -d /run/agenix ]] && rm -rf /run/agenix";
  system.activationScripts.agenixNewGeneration.deps = ["removeAgenixLink"];
}
