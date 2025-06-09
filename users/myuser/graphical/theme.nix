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

  xdg.configFile =
    let
      gtkCss = with config.lib.colors.hex; ''
        @define-color accent_color #${base0D};
        @define-color accent_bg_color #${base0D};
        @define-color accent_fg_color #${base00};
        @define-color destructive_color #${base08};
        @define-color destructive_bg_color #${base08};
        @define-color destructive_fg_color #${base00};
        @define-color success_color #${base0B};
        @define-color success_bg_color #${base0B};
        @define-color success_fg_color #${base00};
        @define-color warning_color #${base0E};
        @define-color warning_bg_color #${base0E};
        @define-color warning_fg_color #${base00};
        @define-color error_color #${base08};
        @define-color error_bg_color #${base08};
        @define-color error_fg_color #${base00};
        @define-color window_bg_color #${base00};
        @define-color window_fg_color #${base05};
        @define-color view_bg_color #${base00};
        @define-color view_fg_color #${base05};
        @define-color headerbar_bg_color #${base01};
        @define-color headerbar_fg_color #${base05};
        @define-color headerbar_border_color ${base01};
        @define-color headerbar_backdrop_color @window_bg_color;
        @define-color headerbar_shade_color rgba(0, 0, 0, 0.07);
        @define-color headerbar_darker_shade_color rgba(0, 0, 0, 0.07);
        @define-color sidebar_bg_color #${base01};
        @define-color sidebar_fg_color #${base05};
        @define-color sidebar_backdrop_color @window_bg_color;
        @define-color sidebar_shade_color rgba(0, 0, 0, 0.07);
        @define-color secondary_sidebar_bg_color @sidebar_bg_color;
        @define-color secondary_sidebar_fg_color @sidebar_fg_color;
        @define-color secondary_sidebar_backdrop_color @sidebar_backdrop_color;
        @define-color secondary_sidebar_shade_color @sidebar_shade_color;
        @define-color card_bg_color #${base01};
        @define-color card_fg_color #${base05};
        @define-color card_shade_color rgba(0, 0, 0, 0.07);
        @define-color dialog_bg_color #${base01};
        @define-color dialog_fg_color #${base05};
        @define-color popover_bg_color #${base01};
        @define-color popover_fg_color #${base05};
        @define-color popover_shade_color rgba(0, 0, 0, 0.07);
        @define-color shade_color rgba(0, 0, 0, 0.07);
        @define-color scrollbar_outline_color #${base02};
        @define-color blue_1 #${base0D};
        @define-color blue_2 #${base0D};
        @define-color blue_3 #${base0D};
        @define-color blue_4 #${base0D};
        @define-color blue_5 #${base0D};
        @define-color green_1 #${base0B};
        @define-color green_2 #${base0B};
        @define-color green_3 #${base0B};
        @define-color green_4 #${base0B};
        @define-color green_5 #${base0B};
        @define-color yellow_1 #${base0A};
        @define-color yellow_2 #${base0A};
        @define-color yellow_3 #${base0A};
        @define-color yellow_4 #${base0A};
        @define-color yellow_5 #${base0A};
        @define-color orange_1 #${base09};
        @define-color orange_2 #${base09};
        @define-color orange_3 #${base09};
        @define-color orange_4 #${base09};
        @define-color orange_5 #${base09};
        @define-color red_1 #${base08};
        @define-color red_2 #${base08};
        @define-color red_3 #${base08};
        @define-color red_4 #${base08};
        @define-color red_5 #${base08};
        @define-color purple_1 #${base0E};
        @define-color purple_2 #${base0E};
        @define-color purple_3 #${base0E};
        @define-color purple_4 #${base0E};
        @define-color purple_5 #${base0E};
        @define-color brown_1 #${base0F};
        @define-color brown_2 #${base0F};
        @define-color brown_3 #${base0F};
        @define-color brown_4 #${base0F};
        @define-color brown_5 #${base0F};
        @define-color light_1 #${base01};
        @define-color light_2 #${base01};
        @define-color light_3 #${base01};
        @define-color light_4 #${base01};
        @define-color light_5 #${base01};
        @define-color dark_1 #${base01};
        @define-color dark_2 #${base01};
        @define-color dark_3 #${base01};
        @define-color dark_4 #${base01};
        @define-color dark_5 #${base01};
      '';
      gtkCssFile = pkgs.writeText "gtk.css" gtkCss;
    in
    {
      "gtk-3.0/gtk.css".source = gtkCssFile;
      "gtk-4.0/gtk.css".source = gtkCssFile;
    };

  home.sessionVariables.GTK_THEME = config.gtk.theme.name;

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "Adwaita-Dark";
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
