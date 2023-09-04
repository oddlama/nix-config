{
  config,
  pkgs,
  ...
}: let
  myuser = config.repo.secrets.global.myuser.name;
in {
  users.groups.${myuser}.gid = config.users.users.${myuser}.uid;
  users.users.${myuser} = {
    uid = 1000;
    inherit (config.repo.secrets.global.myuser) hashedPassword;
    createHome = true;
    group = myuser;
    extraGroups = ["wheel" "input" "video"];
    isNormalUser = true;
    autoSubUidGidRange = false;
    shell = pkgs.zsh;
  };

  # Needed for gtk
  programs.dconf.enable = true;

  age.secrets.my-gpg-pubkey-yubikey = {
    rekeyFile = ./yubikey.gpg.age;
    group = myuser;
    mode = "640";
  };

  home-manager.users.${myuser} = {
    imports = [
      ../common
      ./graphical
      ./neovim

      ./git.nix
      ./dev.nix
      ./gpg.nix
      ./ssh.nix
    ];

    home = {
      inherit (config.users.users.${myuser}) uid;
      username = config.users.users.${myuser}.name;
    };
  };
}
