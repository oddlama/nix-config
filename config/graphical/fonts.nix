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
      pkgs.noto-fonts-emoji
      pkgs.noto-fonts-extra
    ];
  };

  stylix.fonts = {
    serif = {
      package = pkgs.dejavu_fonts;
      name = "IBM Plex Serif";
    };

    sansSerif = {
      package = pkgs.segoe-ui-ttf;
      name = "Segoe UI";
    };

    monospace = {
      # No need for patched nerd fonts, kitty can pick up on them automatically,
      # and ideally every program should do that: https://sw.kovidgoyal.net/kitty/faq/#kitty-is-not-able-to-use-my-favorite-font
      package = pkgs.jetbrains-mono;
      name = "JetBrains Mono";
    };

    emoji = {
      package = pkgs.segoe-ui-ttf;
      name = "Segoe UI Emoji";
    };
  };
}
