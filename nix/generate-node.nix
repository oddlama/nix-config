{
  self,
  agenix,
  agenix-rekey,
  colmena,
  disko,
  home-manager,
  impermanence,
  microvm,
  nixos-nftables-firewall,
  nixpkgs,
  ...
} @ inputs: {
  # The name of the generated node
  name,
  # Additional modules that should be imported
  modules ? [],
  # The system in use
  system,
  ...
}: {
  inherit system;
  pkgs = self.pkgs.${system};
  specialArgs = {
    inherit (nixpkgs) lib;
    inherit (self) nodes;
    inherit inputs;
  };
  imports =
    modules
    ++ [
      {node.name = name;}
      agenix.nixosModules.default
      agenix-rekey.nixosModules.default
      disko.nixosModules.disko
      home-manager.nixosModules.default
      impermanence.nixosModules.impermanence
      nixos-nftables-firewall.nixosModules.default
    ];
}
