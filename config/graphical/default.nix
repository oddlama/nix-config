{
  config,
  lib,
  minimal,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    types
    optionalAttrs
    ;
in
{
  options.graphical.gaming.enable = mkOption {
    description = "Enables gaming on this machine and will add a lot of gaming related packages and configuration.";
    default = false;
    type = types.bool;
  };
}
// optionalAttrs (!minimal) {
  imports = [
    ./fonts.nix
    ./steam.nix
    ./xserver.nix
  ];

  config = {
    # For Star Citizen. See https://github.com/starcitizen-lug/knowledge-base/wiki for more info.
    boot.kernel.sysctl = mkIf config.graphical.gaming.enable {
      "vm.max_map_count" = 16777216;
      "fs.file-max" = 524288;
    };

    # Needed for gtk
    programs.dconf.enable = true;
    # Required for gnome3 pinentry
    services.dbus.packages = [ pkgs.gcr ];

    # We actually use the home-manager module to add the actual portal config,
    # but need this so relevant implementations are found
    environment.pathsToLink = [
      "/share/xdg-desktop-portal"
    ];

    services.displayManager.enable = true;
    programs.uwsm = {
      enable = true;
      waylandCompositors.sway = {
        prettyName = "Sway";
        comment = "Sway";
        binPath = lib.getExe pkgs.sway;
      };

      waylandCompositors.hyprland = {
        prettyName = "Hyprland";
        comment = "Hyprland";
        binPath = lib.getExe pkgs.hyprland;
      };
    };
  };
}
