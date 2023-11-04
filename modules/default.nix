{inputs, ...}: {
  disabledModules = ["services/security/kanidm.nix"];
  imports = [
    inputs.agenix-rekey.nixosModules.default
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.elewrap.nixosModules.default
    inputs.home-manager.nixosModules.default
    inputs.impermanence.nixosModules.impermanence
    inputs.nixos-nftables-firewall.nixosModules.default

    ../users/root

    ./config/boot.nix
    ./config/home-manager.nix
    ./config/impermanence.nix
    ./config/inputrc.nix
    ./config/issue.nix
    ./config/microvms.nix
    ./config/net.nix
    ./config/nftables.nix
    ./config/nix.nix
    ./config/resolved.nix
    ./config/secrets.nix
    ./config/ssh.nix
    ./config/system.nix
    ./config/users.nix

    ./meta/kanidm.nix
    ./meta/microvms.nix
    ./meta/nginx.nix
    ./meta/oauth2-proxy.nix
    ./meta/promtail.nix
    ./meta/telegraf.nix
    ./meta/wireguard.nix
    ./meta/wireguard-proxy.nix

    ./networking/interface-naming.nix
    ./networking/provided-domains.nix

    ./repo/distributed-config.nix
    ./repo/meta.nix
    ./repo/secrets.nix

    ./security/acme-wildcard.nix

    ./system/deterministic-ids.nix
  ];

  nixpkgs.overlays = [
    inputs.microvm.overlay
    inputs.nixpkgs-wayland.overlay
    inputs.nixvim.overlays.default
    inputs.wired-notify.overlays.default
  ];
}
