{config, ...}: {
  imports = [
    ./impermanence.nix
    ./inputrc.nix
    ./issue.nix
    ./net.nix
    ./nix.nix
    ./resolved.nix
    ./ssh.nix
    ./system.nix
    ./xdg.nix

    ../../../modules/wireguard.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    verbose = true;
  };

  # Required even when using home-manager's zsh module since the /etc/profile load order
  # is partly controlled by this. See nix-community/home-manager#3681.
  programs.zsh.enable = true;
}
