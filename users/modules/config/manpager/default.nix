{pkgs, ...}: let
  nvimPager = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped nvimConfig;
  nvimConfig =
    pkgs.neovimUtils.makeNeovimConfig {
      wrapRc = false;
      withPython3 = false;
      withRuby = false;
    }
    // {
      wrapperArgs = ["--add-flags" "--clean -u ${./init.lua}"];
    };
in {
  home.sessionVariables.MANPAGER = "${nvimPager}/bin/nvim '+Man!'";
}
