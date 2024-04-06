{...}: {
  imports = [
    ./uid.nix
    ./secrets.nix

    ./config/htop.nix
    ./config/impermanence.nix
    ./config/neovim.nix
    ./config/shell
    ./config/utils.nix
  ];

  xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";
}
