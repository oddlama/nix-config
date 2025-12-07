{ pkgs, ... }:
{
  fonts = {
    # Always prefer emojis even if the original font would provide a glyph
    fontconfig.localConf = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
          <alias binding="weak">
              <family>monospace</family>
              <prefer>
                  <family>emoji</family>
              </prefer>
          </alias>
          <alias binding="weak">
              <family>sans-serif</family>
              <prefer>
                  <family>emoji</family>
              </prefer>
          </alias>
          <alias binding="weak">
              <family>serif</family>
              <prefer>
                  <family>emoji</family>
              </prefer>
          </alias>
      </fontconfig>
    '';

    packages = [
      pkgs.nerd-fonts.symbols-only
      pkgs.noto-fonts
      pkgs.noto-fonts-cjk-sans
      pkgs.noto-fonts-cjk-serif
      pkgs.noto-fonts-color-emoji
      pkgs.noto-fonts

      pkgs.dejavu_fonts
      pkgs.segoe-ui-ttf
      pkgs.jetbrains-mono
    ];

    fontconfig.defaultFonts = {
      serif = [ "IBM Plex Serif" ];
      sansSerif = [ "Segoe UI" ];
      emoji = [ "Segoe UI Emoji" ];
      monospace = [
        # No need for patched nerd fonts, kitty can pick up on them automatically,
        # and ideally every program should do that: https://sw.kovidgoyal.net/kitty/faq/#kitty-is-not-able-to-use-my-favorite-font
        "JetBrains Mono"
      ];
    };
  };
}
