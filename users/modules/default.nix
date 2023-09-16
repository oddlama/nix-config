{...}: {
  imports = [
    ./secrets.nix
    ./uid.nix

    ./config/htop.nix
    ./config/impermanence.nix
    ./config/neovim.nix
    ./config/shell
    ./config/utils.nix
  ];
}
