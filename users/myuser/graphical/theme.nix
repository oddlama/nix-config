{
  lib,
  pkgs,
  ...
}: {
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  xresources.properties = {
    "Xft.hinting" = true;
    "Xft.antialias" = true;
    "Xft.autohint" = false;
    "Xft.lcdfilter" = "lcddefault";
    "Xft.hintstyle" = "hintfull";
    "Xft.rgba" = "rgb";
  };

  gtk = let
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
  in {
    enable = true;

    iconTheme = {
      name = "WhiteSur-dark";
      package = pkgs.whitesur-icon-theme;
    };

    # TODO test other themes
    theme = lib.mkForce {
      name = "WhiteSur-Dark-solid";
      package = pkgs.whitesur-gtk-theme;
    };

    gtk2.extraConfig = "gtk-application-prefer-dark-theme = true";
    gtk3.extraConfig = gtk34extraConfig;
    gtk4.extraConfig = gtk34extraConfig;
  };

  home.sessionVariables.GTK_THEME = "WhiteSur-Dark-solid";

  qt = {
    enable = true;
    platformTheme = "gtk";
  };

  stylix = {
    polarity = "dark";
    base16Scheme = {
      base00 = "282c34";
      base01 = "353b45";
      base02 = "3e4451";
      base03 = "545862";
      base04 = "565c64";
      base05 = "abb2bf";
      base06 = "b6bdca";
      base07 = "c8ccd4";
      base08 = "e06c75";
      base09 = "d19a66";
      base0A = "e5c07b";
      base0B = "98c379";
      base0C = "56b6c2";
      base0D = "61afef";
      base0E = "c678dd";
      base0F = "be5046";
    };
    targets.gtk.enable = true;
  };
}
