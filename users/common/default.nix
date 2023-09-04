{...}: {
  imports = [
    ./modules/uid.nix

    ./htop.nix
    ./impermanence.nix
    ./neovim.nix
    ./shell
    ./utils.nix
  ];
}
