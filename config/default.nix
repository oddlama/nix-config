{ inputs, ... }:
{
  # Not setting this causes infinite recursion because it has a very weird default.
  # The default should probably be removed upstream and only applied with mkDefault
  # if hardware.nvidia.enable is true
  hardware.nvidia.modesetting.enable = true;

  imports = [
    inputs.agenix-rekey.nixosModules.default
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.elewrap.nixosModules.default
    inputs.home-manager.nixosModules.default
    inputs.idmail.nixosModules.default
    inputs.impermanence.nixosModules.impermanence
    inputs.nix-topology.nixosModules.default
    (inputs.nixos-extra-modules + "/modules")
    inputs.nixos-nftables-firewall.nixosModules.default

    ../modules

    ../users/root

    ./boot.nix
    ./home-manager.nix
    ./impermanence.nix
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
