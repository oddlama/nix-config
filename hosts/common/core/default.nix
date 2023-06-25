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

    ../../../users/root

    ../../../modules/deteministic-ids.nix
    ../../../modules/distributed-config.nix
    ../../../modules/extra.nix
    ../../../modules/interface-naming.nix
    ../../../modules/microvms.nix
    ../../../modules/oauth2-proxy.nix
    ../../../modules/promtail.nix
    ../../../modules/provided-domains.nix
    ../../../modules/repo.nix
    ../../../modules/telegraf.nix
    ../../../modules/wireguard.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    verbose = true;
  };

  # If the host defines microvms, ensure that this core module and
  # some boilerplate is imported automatically.
  extra.microvms.commonImports = [
    ./.
    {home-manager.users.root.home.minimal = true;}
  ];

  # Required even when using home-manager's zsh module since the /etc/profile load order
  # is partly controlled by this. See nix-community/home-manager#3681.
  programs.zsh.enable = true;
}
