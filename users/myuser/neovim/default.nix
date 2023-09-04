{pkgs, ...}: {
  programs.neovim = {
    withPython3 = true;
    extraPython3Packages = pyPkgs: with pyPkgs; [openai];
    withNodeJs = true;
  };

  xdg.configFile = {
    "nvim/lua".source = ./lua;
    "nvim/init.lua".source = ./init.lua;
  };

  # TODO NO! NO! all of this goes away
  home.packages = with pkgs; [gcc shellcheck stylua];
}
