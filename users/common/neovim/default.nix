{
  lib,
  pkgs,
  ...
}: {
  programs = {
    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      withPython3 = true;
      extraPython3Packages = pyPkgs: with pyPkgs; [openai];
      withNodeJs = true;
      defaultEditor = true;
    };
  };
  xdg.configFile."nvim/lua".source = ./lua;
  xdg.configFile."nvim/init.lua".source = ./init.lua;
  home.packages = with pkgs; [gcc shellcheck stylua];
}
