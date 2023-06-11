{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./minimal.nix
  ];

  config = lib.mkIf (!config.home.minimal) {
    programs.neovim = {
      withPython3 = true;
      extraPython3Packages = pyPkgs: with pyPkgs; [openai];
      withNodeJs = true;
    };
    xdg.configFile = {
      "nvim/lua".source = ./lua;
      "nvim/init.lua".source = ./init.lua;
    };
    home.packages = with pkgs; [gcc shellcheck stylua];
  };
}
