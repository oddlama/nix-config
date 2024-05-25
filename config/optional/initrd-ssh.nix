{
  config,
  pkgs,
  ...
}: {
  age.secrets.initrd_host_ed25519_key.generator.script = "ssh-ed25519";

  boot.initrd.network.enable = true;
  boot.initrd.network.ssh = {
    enable = true;
    port = 4;
    hostKeys = [config.age.secrets.initrd_host_ed25519_key.path];
  };

  # Make sure that there is always a valid initrd hostkey available that can be installed into
  # the initrd. When bootstrapping a system (or re-installing), agenix cannot succeed in decrypting
  # whatever is given, since the correct hostkey doesn't even exist yet. We still require
  # a valid hostkey to be available so that the initrd can be generated successfully.
  # The correct initrd host-key will be installed with the next update after the host is booted
  # for the first time, and the secrets were rekeyed for the the new host identity.
  system.activationScripts.agenixEnsureInitrdHostkey = {
    text = ''
      [[ -e ${config.age.secrets.initrd_host_ed25519_key.path} ]] \
        || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${config.age.secrets.initrd_host_ed25519_key.path}
    '';
    deps = ["agenixInstall" "users"];
  };
  system.activationScripts.agenixChown.deps = ["agenixEnsureInitrdHostkey"];
}
