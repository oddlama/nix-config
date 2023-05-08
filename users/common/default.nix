{pkgs, ...}: {
  imports = [
    ./modules/uid.nix
    ./modules/minimal.nix

    ./git.nix
    ./htop.nix
    ./neovim
    ./shell
    ./utils.nix
  ];

  xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";
}
