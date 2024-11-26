{
  config,
  lib,
  pkgs,
  ...
}:
let
  colors = config.lib.stylix.colors.withHashtag;
in
{
  xdg.configFile."flameshot/flameshot.ini".source = (pkgs.formats.ini { }).generate "flameshot.ini" {
    General = {
      antialiasingPinZoom = false;
      buttons = ''@Variant(\0\0\0\x7f\0\0\0\vQList<int>\0\0\0\0\x10\0\0\0\0\0\0\0\x3\0\0\0\x4\0\0\0\x5\0\0\0\x6\0\0\0\x12\0\0\0\xf\0\0\0\x13\0\0\0\a\0\0\0\t\0\0\0\x10\0\0\0\n\0\0\0\v\0\0\0\x17\0\0\0\f\0\0\0\x11)'';
      checkForUpdates = false;
      contrastOpacity = 190;
      contrastUiColor = colors.base0A;
      disabledTrayIcon = true;
      drawColor = colors.base08;
      filenamePattern = "%Y-%m-%dT%H:%M:%S%z";
      savePath = "${config.xdg.userDirs.pictures}/screenshots";
      showHelp = false;
      showStartupLaunchMessage = false;
      uiColor = colors.base0F;
      userColors = lib.concatStringsSep "," [
        "picker"
        colors.base00
        colors.base01
        colors.base02
        colors.base03
        colors.base04
        colors.base05
        colors.base06
        colors.base07
        colors.base08
        colors.base09
        colors.base0A
        colors.base0B
        colors.base0C
        colors.base0D
        colors.base0E
        colors.base0F
      ];
    };
    Shortcuts = {
      TYPE_EXIT = "Q";
      TYPE_REDO = "Ctrl+Y";
    };
  };
}
