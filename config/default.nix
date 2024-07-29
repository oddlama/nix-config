{inputs, ...}: {
  disabledModules = [
    "services/security/kanidm.nix"
    "services/networking/netbird.nix"
  ];

  hardware.nvidia.modesetting.enable = builtins.trace "remove once #330748 is merged" true;

  imports = [
    inputs.agenix-rekey.nixosModules.default
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.elewrap.nixosModules.default
    inputs.home-manager.nixosModules.default
    inputs.idmail.nixosModules.default
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
    ./installer.nix
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
}
