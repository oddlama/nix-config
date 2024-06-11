{pkgs, ...}: {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    extraConfig = {
      matching = "fuzzy";
      terminal = "kitty";
    };
  };

  home.file = let
    rofi-themes = pkgs.fetchFromGitHub {
      owner = "adi1090x";
      repo = "rofi";
      rev = "3a28753b0a8fb666f4bd0394ac4b0e785577afa2";
      hash = "sha256-G3sAyIZbq1sOJxf+NBlXMOtTMiBCn6Sat8PHryxRS0w=";
    };
  in {
    ".config/rofi/colors" = {
      source = "${rofi-themes}/files/colors";
      recursive = true;
    };
    ".config/rofi/launchers/type-1/style-10.rasi".source = "${rofi-themes}/files/launchers/type-1/style-10.rasi";
    ".config/rofi/launchers/type-1/shared/colors.rasi".text =
      /*
      css
      */
      ''
        @import "~/.config/rofi/colors/onedark.rasi"
      '';
    ".config/rofi/launchers/type-1/shared/fonts.rasi".text = "";
  };
}
