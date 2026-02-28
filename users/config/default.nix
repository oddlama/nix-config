{
  imports = [
    ../modules

    ./htop.nix
    ./impermanence.nix
    ./neovim.nix
    ./shell
    ./utils.nix
  ];

  xdg.configFile."nixpkgs/config.nix".text =
    "{ segger-jlink.acceptLicense = true; allowUnfree = true; }";
}
