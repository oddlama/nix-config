{
  config,
  lib,
  nixosConfig,
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

  home.sessionVariables.GTK_THEME = config.gtk.theme.name;

  qt = {
    enable = true;
    platformTheme = "gtk";
  };

  stylix = {
    inherit (nixosConfig.stylix) polarity base16Scheme;
    targets.gtk.enable = true;
  };
}
