{pkgs, ...}: {
  programs.neovim = {
    withPython3 = true;
    extraPython3Packages = pyPkgs: with pyPkgs; [openai];
    withNodeJs = true;
  };

  xdg.configFile = {
    "nvim/ftplugin".source = ./ftplugin;
    "nvim/init.lua".source = ./init.lua;
    "nvim/lua".source = ./lua;
  };

  # TODO NO! NO! all of this goes away
  home.packages = with pkgs; [gcc shellcheck stylua];
}
