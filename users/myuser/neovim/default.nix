{
  config,
  pkgs,
  ...
}: {
  programs.neovim-custom.package = let
    nvimConfig =
      pkgs.neovimUtils.makeNeovimConfig {
        wrapRc = false;
        withPython3 = true;
        withRuby = true;
        withNodeJs = true;
        #extraPython3Packages = p: [];
        #plugins = [
        #  { plugin = pkgs.; config = ''''; optional = false; }
        #];
      }
      // {
        wrapperArgs = ["--add-flags" "--clean -u ${./aaa/init.lua}"];
      };
  in
    pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped nvimConfig;

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
  home.sessionVariables.E = "${config.programs.neovim-custom.package}/bin/nvim";
}
