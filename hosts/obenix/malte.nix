{
  config,
  globals,
  lib,
  pkgs,
  ...
}:
{
  users.groups.malte.gid = config.users.users.malte.uid;
  users.users.malte = {
    uid = 1000;
    inherit (globals.malte) hashedPassword;
    group = "malte";
    # Required to use nix
    extraGroups = [ "wheel" ];
    isNormalUser = true;
    autoSubUidGidRange = false;
    shell = pkgs.zsh;
    # Same keys as root (the YubiKey)
    openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
  };

  # This is just a space to work in, so keep everything in it
  environment.persistence."/persist".directories = [
    {
      directory = config.users.users.malte.home;
      user = "malte";
      group = "malte";
      mode = "0700";
    }
  ];

  # Only the shared base config, not the full personal one from users/malte
  home-manager.users.malte = {
    imports = [ ../../users/config ];

    home.username = config.users.users.malte.name;

    # The whole home is persisted already, so persisting single directories in
    # /persist again would only bind mount them onto themselves. Disposable
    # state from the shared config (caches etc.) still goes to /state.
    home.persistence."/persist" = lib.mkForce { };
  };
}
