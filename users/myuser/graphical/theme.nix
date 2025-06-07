{
  config,
  lib,
  pkgs,
  ...
}:
{
  xresources.properties = {
    "Xft.hinting" = true;
    "Xft.antialias" = true;
    "Xft.autohint" = false;
    "Xft.lcdfilter" = "lcddefault";
    "Xft.hintstyle" = "hintfull";
    "Xft.rgba" = "rgb";
  };

  gtk =
    let
      gtk34extraConfig = {
        gtk-application-prefer-dark-theme = 1;
        gtk-cursor-theme-size = 32;
        gtk-enable-animations = true;
        gtk-xft-antialias = 1;
        gtk-xft-dpi = 160; # XXX: delete for wayland?
        gtk-xft-hinting = 1;
        gtk-xft-hintstyle = "hintfull";
        gtk-xft-rgba = "rgb";
      };
    in
    {
      enable = true;

      iconTheme = {
        name = "WhiteSur-dark";
        package = pkgs.whitesur-icon-theme;
      };

      font = {
        package = pkgs.segoe-ui-ttf;
        name = "Segoe UI";
        size = 10;
      };

      theme = {
        package = pkgs.adw-gtk3;
        name = "adw-gtk3";
      };

      gtk2.extraConfig = "gtk-application-prefer-dark-theme = true";
      gtk3.extraConfig = gtk34extraConfig;
      gtk4.extraConfig = gtk34extraConfig;
    };

  home.sessionVariables.GTK_THEME = config.gtk.theme.name;

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    size = 20;
    package = pkgs.bibata-cursors;
    x11.enable = true;
    gtk.enable = true;
  };

  lib.colors = rec {
    withHashtag = lib.mapAttrs (_: v: "#${v}") hex;
    hex = {
      base00 = "101419";
      base01 = "171b20";
      base02 = "21262e";
      base03 = "242931";
      base04 = "485263";
      base05 = "b6beca";
      base06 = "dee1e6";
      base07 = "e3e6eb";
      base08 = "e05f65";
      base09 = "f9a872";
      base0A = "f1cf8a";
      base0B = "78dba9";
      base0C = "74bee9";
      base0D = "70a5eb";
      base0E = "c68aee";
      base0F = "9378de";
    };
  };
}
