{
  config,
  lib,
  pkgs,
  ...
}: let
  myuser = config.repo.secrets.global.myuser.name;
  mkUserDirs = map (directory: {
    inherit directory;
    mode = "700";
  });
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

  # TODO age.secrets = mapAttrs user.hmConfig.cfg.age.secrets users
  age.secrets.my-gpg-pubkey-yubikey = {
    rekeyFile = ./yubikey.gpg.age;
    group = myuser;
    mode = "640";
  };

  # TODO numlock default on in sway and kernel console
  # TODO make dataset for safe/persist/ and automount it
  # TODO modularized based on hmConfig
  environment.persistence."/state".users.${myuser}.directories =
    mkUserDirs
    [
      ".cache/fontconfig"
      ".cache/mozilla"
      ".cache/nix" # nix eval cache
      ".cache/nix-index"
      ".cache/nvidia" # GLCache
      ".cache/nvim"
      ".local/share/nvim"
      ".local/state/direnv"
      ".local/state/nix"
      ".local/state/nvim"
      ".local/state/wireplumber"
      "Downloads"
    ];

  environment.persistence."/persist".users.${myuser}.directories =
    mkUserDirs
    [
      ".mozilla"
      ".config/discord" # Bad Discord! BAD! Saves state in ,config tststs
      ".config/Signal" # L take, electron.
      ".local/share/atuin"
      ".local/share/nix" # Repl history
      "projects"
    ];

  home-manager.users.${myuser} = {
    imports = [
      ../common
      ./graphical
      ./neovim

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
