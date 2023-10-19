{
  config,
  pkgs,
  ...
}: {
  programs.neovim-custom = {
    config = {
      withPython3 = false;
      withRuby = false;
      withNodeJs = false;
      #extraPython3Packages = p: [];
      plugins = with pkgs.vimPlugins; [
        {
          plugin = neo-tree-nvim;
          config =
            /*
            lua
            */
            ''
              require("neo-tree").setup {}
            '';
        }
      ];
    };
    init = builtins.readFile ./aaa/init.lua;
  };

  home.packages = let
    nvimConfig = pkgs.neovimUtils.makeNeovimConfig {
      wrapRc = false;
      withPython3 = true;
      withRuby = true;
      withNodeJs = true;
      extraPython3Packages = p: with p; [openai];
    };
  in [(pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped nvimConfig)];

  xdg.configFile = {
    "nvim/ftplugin".source = ./ftplugin;
    "nvim/init.lua".source = ./init.lua;
    "nvim/lua".source = ./lua;
  };
}
