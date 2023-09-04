{
  lib,
  pkgs,
  ...
}: {
  fonts = {
    fontconfig.defaultFonts = {
      sansSerif = lib.mkBefore ["Segoe UI"];
      #serif = [];
      monospace = ["FiraCode Nerd Font"];
      emoji = ["Segoe UI Emoji" "Noto Fonts Emoji"];
    };

    packages = with pkgs; [
      (nerdfonts.override {fonts = ["FiraCode"];})
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-emoji
      noto-fonts-extra
      segoe-ui-ttf
    ];
  };
}
