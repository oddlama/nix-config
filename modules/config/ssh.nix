{lib, ...}: {
  services.openssh = {
    enable = true;
    # In containers, this is true by default, but we don't want that
    # because we rely on ssh key generation for agenix
    startWhenNeeded = lib.mkForce false;
    authorizedKeysFiles = lib.mkForce ["/etc/ssh/authorized_keys.d/%u"];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "yes";
    };
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };
}
