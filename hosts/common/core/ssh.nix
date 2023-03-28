{lib, ...}: {
  services.openssh = {
    enable = true;
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
