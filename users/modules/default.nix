{...}: {
  imports = [
    ./deadd-notification-center.nix
    ./uid.nix
    ./secrets.nix
    ./neovim.nix

    ./config/htop.nix
    ./config/impermanence.nix
    ./config/manpager
    ./config/neovim.nix
    ./config/shell
    ./config/utils.nix
  ];

  xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";
}
