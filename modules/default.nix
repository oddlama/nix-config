{inputs, ...}: {
  disabledModules = ["services/security/kanidm.nix"];
  imports = [
    inputs.agenix-rekey.nixosModules.default
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.elewrap.nixosModules.default
    inputs.nixos-extra-modules.nixosModules.default
    inputs.home-manager.nixosModules.default
    inputs.impermanence.nixosModules.impermanence
    inputs.nixos-nftables-firewall.nixosModules.default

    ../users/root

    ./config/boot.nix
    ./config/home-manager.nix
    ./config/impermanence.nix
    ./config/inputrc.nix
    ./config/issue.nix
    ./config/net.nix
    ./config/nftables.nix
    ./config/nix.nix
    ./config/resolved.nix
    ./config/secrets.nix
    ./config/ssh.nix
    ./config/system.nix
    ./config/users.nix

    ./acme-wildcard.nix
    ./backups.nix
    ./deterministic-ids.nix
    ./distributed-config.nix
    ./kanidm.nix
    ./meta.nix
    ./oauth2-proxy.nix
    ./promtail.nix
    ./provided-domains.nix
    ./secrets.nix
    ./telegraf.nix
    ./wireguard-proxy.nix
    ./wireguard.nix

    ./topology.nix
  ];

  nixpkgs.overlays = [
    inputs.nixpkgs-wayland.overlay
    inputs.nixvim.overlays.default
    inputs.wired-notify.overlays.default
  ];
}
