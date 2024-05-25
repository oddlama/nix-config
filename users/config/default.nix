{
  imports = [
    ../modules

    ./htop.nix
    ./impermanence.nix
    ./neovim.nix
    ./shell
    ./utils.nix
  ];

  xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";
}
