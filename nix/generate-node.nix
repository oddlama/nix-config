{
  self,
  agenix,
  agenix-rekey,
  disko,
  elewrap,
  home-manager,
  impermanence,
  nixos-nftables-firewall,
  nixseparatedebuginfod,
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
    inherit (self.pkgs.${system}) lib;
    inherit (self) nodes;
    inherit inputs;
  };
  imports =
    modules
    ++ [
      {node.name = name;}
      agenix-rekey.nixosModules.default
      agenix.nixosModules.default
      disko.nixosModules.disko
      elewrap.nixosModules.default
      home-manager.nixosModules.default
      impermanence.nixosModules.impermanence
      nixos-nftables-firewall.nixosModules.default
      nixseparatedebuginfod.nixosModules.default
    ];
}
