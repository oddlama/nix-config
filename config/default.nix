{inputs, ...}: {
  disabledModules = [
    "services/security/kanidm.nix"
    "services/networking/netbird.nix"
  ];

  imports = [
    inputs.agenix-rekey.nixosModules.default
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.elewrap.nixosModules.default
    inputs.home-manager.nixosModules.default
    inputs.impermanence.nixosModules.impermanence
    inputs.nix-topology.nixosModules.default
    inputs.nixos-extra-modules.nixosModules.default
    inputs.nixos-nftables-firewall.nixosModules.default

    ../modules

    ../users/root

    ./boot.nix
    ./home-manager.nix
    ./impermanence.nix
    ./inputrc.nix
    ./issue.nix
    ./net.nix
    ./nftables.nix
    ./nix.nix
    ./resolved.nix
    ./secrets.nix
    ./ssh.nix
    ./system.nix
    ./topology.nix
    ./users.nix
  ];

  nixpkgs.overlays = [
    inputs.nixvim.overlays.default
    inputs.wired-notify.overlays.default
  ];
}
