{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  users.groups.myuser.gid = config.users.users.myuser.uid;
  users.users.myuser = {
    uid = 1000;
    createHome = true;
    group = "myuser";
    extraGroups =
      ["wheel" "input" "video"]
      ++ optionals config.sound.enable ["audio"];
    isNormalUser = true;
    shell = pkgs.zsh;
  };

  home-manager.users.myuser = {
    imports = [
      #impermanence.home-manager.impermanence
      ./core
      ./dev
      ./modules
      #]
      #++ optionals config.programs.sway.enable [
      #  ./graphical
      #  ./graphical/sway
      #] ++ optionals config.services.xserver.windowManager.i3.enable [
      #  ./graphical
      #  ./graphical/i3
    ];

    home.username = config.users.users.myuser.name;
    home.uid = config.users.users.myuser.uid;
  };
}
