{
  config,
  inputs,
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
    inputs.stylix.nixosModules.stylix
    inputs.whisper-overlay.nixosModules.default

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

    xdg.portal = {
      wlr.enable = true;
      enable = true;
      xdgOpenUsePortal = true;
      config.common = {
        default = [
          "wlr"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "xdg-desktop-portal-wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "xdg-desktop-portal-wlr" ];
        "org.freedesktop.portal.FileChooser" = [ "xdg-desktop-portal-gtk" ];
      };
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];
    };

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

    stylix = {
      enable = true;
      # I want to choose what to style myself.
      autoEnable = false;
      image = config.lib.stylix.pixel "base00";

      polarity = "dark";

      # onedark
      # base16Scheme = {
      #   base00 = "#282c34";
      #   base01 = "#353b45";
      #   base02 = "#3e4451";
      #   base03 = "#545862";
      #   base04 = "#565c64";
      #   base05 = "#abb2bf";
      #   base06 = "#b6bdca";
      #   base07 = "#c8ccd4";
      #   base08 = "#e06c75";
      #   base09 = "#d19a66";
      #   base0A = "#e5c07b";
      #   base0B = "#98c379";
      #   base0C = "#56b6c2";
      #   base0D = "#61afef";
      #   base0E = "#c678dd";
      #   base0F = "#9378de";
      # };

      # based on decaycs-dark, normal variant
      base16Scheme = {
        base00 = "#101419";
        base01 = "#171b20";
        base02 = "#21262e";
        base03 = "#242931";
        base04 = "#485263";
        base05 = "#b6beca";
        base06 = "#dee1e6";
        base07 = "#e3e6eb";
        base08 = "#e05f65";
        base09 = "#f9a872";
        base0A = "#f1cf8a";
        base0B = "#78dba9";
        base0C = "#74bee9";
        base0D = "#70a5eb";
        base0E = "#c68aee";
        base0F = "#9378de";
      };

      ## based on decaycs-dark, bright variant
      #base16Scheme = {
      #  base00 = "#101419";
      #  base01 = "#171B20";
      #  base02 = "#21262e";
      #  base03 = "#242931";
      #  base04 = "#485263";
      #  base05 = "#b6beca";
      #  base06 = "#dee1e6";
      #  base07 = "#e3e6eb";
      #  base08 = "#e5646a";
      #  base09 = "#f7b77c";
      #  base0A = "#f6d48f";
      #  base0B = "#94F7C5";
      #  base0C = "#79c3ee";
      #  base0D = "#75aaf0";
      #  base0E = "#cb8ff3";
      #  base0F = "#9d85e1";
      #};
    };
  };
}
