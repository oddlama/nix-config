{pkgs, ...}: {
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 32;
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
    font = {
      package = pkgs.segoe-ui-ttf;
      name = "Segoe UI";
    };

    iconTheme = {
      name = "WhiteSur-dark";
      package = pkgs.whitesur-icon-theme;
    };

    theme = {
      name = "WhiteSur-dark-solid";
      package = pkgs.whitesur-gtk-theme;
    };

    gtk2.extraConfig = "gtk-application-prefer-dark-theme = true";
    gtk3.extraConfig = gtk34extraConfig;
    gtk4.extraConfig = gtk34extraConfig;
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = {
      name = "adwaita";
      package = pkgs.adwaita-qt;
    };
  };
}
