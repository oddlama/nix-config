{
  config,
  pkgs,
  nodePath,
  ...
}: {
  rekey.secrets.initrd_host_ed25519_key.file = nodePath + "/secrets/initrd_host_ed25519_key.age";

  boot.initrd.network.enable = true;
  boot.initrd.network.ssh = {
    enable = true;
    port = 4;
    hostKeys = [config.rekey.secrets.initrd_host_ed25519_key.path];
  };

  # Make sure that there is always a valid initrd hostkey available that can be installed into
  # the initrd. When bootstrapping a system (or re-installing), agenix cannot succeed in decrypting
  # whatever is given, since the correct hostkey doesn't even exist yet. We still require
  # a valid hostkey to be available so that the initrd can be generated successfully.
  # The correct initrd host-key will be installed with the next update after the host is booted
  # for the first time, and the secrets were rekeyed for the the new host identity.
  system.activationScripts.agenixEnsureInitrdHostkey = {
    text = ''
      [[ -e ${config.rekey.secrets.initrd_host_ed25519_key.path} ]] \
        || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${config.rekey.secrets.initrd_host_ed25519_key.path}
    '';
    deps = ["agenixInstall"];
  };
  system.activationScripts.agenixChown.deps = ["agenixEnsureInitrdHostkey"];
}
