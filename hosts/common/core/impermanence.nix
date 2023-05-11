{
  # State that should be kept across reboots, but is otherwise
  # NOT important information in any way that needs to be backed up.
  #environment.persistence."/nix/state" = {
  #  hideMounts = true;
  #  files = [
  #  ];
  #  directories = [
  #  ];
  #};

  # Give agenix access to the hostkey independent of impermanence activation
  age.identityPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];

  # State that should be kept forever, and backed up accordingly.
  environment.persistence."/persist" = {
    hideMounts = true;
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
    directories = [
      "/var/log"
      "/var/lib/nixos"
    ];
  };
}
