{
  self,
  agenix,
  agenix-rekey,
  colmena,
  disko,
  home-manager,
  impermanence,
  microvm,
  nixos-hardware,
  nixos-nftables-firewall,
  nixpkgs,
  ...
} @ inputs: let
  inherit (nixpkgs.lib) optionals;
in
  nodeName: nodeMeta: {
    inherit (nodeMeta) system;
    pkgs = self.pkgs.${nodeMeta.system};
    specialArgs = {
      inherit (nixpkgs) lib;
      inherit (self) extraLib nodes;
      inherit inputs;
      inherit nodeName;
      secrets = self.secrets.content;
      nodeSecrets = self.secrets.content.nodes.${nodeName};
      nixos-hardware = nixos-hardware.nixosModules;
    };
    imports =
      [
        (../hosts + "/${nodeName}")
        agenix.nixosModules.default
        agenix-rekey.nixosModules.default
        disko.nixosModules.disko
        home-manager.nixosModules.default
        impermanence.nixosModules.impermanence
        nixos-nftables-firewall.nixosModules.default
      ]
      ++ optionals (nodeMeta.microVmHost or false) [
        microvm.nixosModules.host
      ]
      ++ optionals (nodeMeta.type == "microvm") [
        microvm.nixosModules.microvm
      ];
  }
