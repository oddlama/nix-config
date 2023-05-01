{
  config,
  lib,
  pkgs,
  secrets,
  stateVersion,
  ...
}:
with lib; let
  inherit (secrets) myuser;
in {
  users.groups.${myuser}.gid = config.users.users.${myuser}.uid;
  users.users.${myuser} = {
    uid = 1000;
    hashedPassword = "$6$YogAnKRz8qW2Gz.I$chgMKKrpPAfV0WuGN6ChOgUJistpCzFsHOT6mhHyj07mwI1kSfDJvnMB13frMvkpv2aGpXHVH.yxk5fYHeeET/";
    createHome = true;
    group = myuser;
    extraGroups =
      ["wheel" "input" "video"]
      ++ optionals config.sound.enable ["audio"];
    isNormalUser = true;
    shell = pkgs.zsh;
  };

  home-manager.users.${myuser} = {
    imports = [
      #impermanence.home-manager.impermanence
      ../common
      ./dev.nix
      ./gpg.nix
      ./ssh.nix
    ];

    home = {
      inherit stateVersion;
      inherit (config.users.users.${myuser}) uid;
      username = config.users.users.${myuser}.name;
      shellAliases = {
        p = "cd ~/projects";
      };
    };
  };
}
