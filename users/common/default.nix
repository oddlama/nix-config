{pkgs, ...}: {
  imports = [
    ./modules/uid.nix

    ./git.nix
    ./htop.nix
    ./neovim.nix
    ./shell
    ./utils.nix
  ];

  xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";
}
