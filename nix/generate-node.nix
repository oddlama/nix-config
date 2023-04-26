{
  self,
  colmena,
  disko,
  home-manager,
  #impermanence,
  nixos-hardware,
  nixos-nftables-firewall,
  nixpkgs,
  microvm,
  agenix,
  agenix-rekey,
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
      inherit nodeMeta;
      secrets = self.secrets.content;
      nodeSecrets = self.secrets.content.nodes.${nodeName};
      nixos-hardware = nixos-hardware.nixosModules;
      #impermanence = impermanence.nixosModules;
    };
    imports =
      [
        (../hosts + "/${nodeName}")
        home-manager.nixosModules.default
        #impermanence.nixosModules.default
        agenix.nixosModules.default
        agenix-rekey.nixosModules.default
        disko.nixosModules.disko
        nixos-nftables-firewall.nixosModules.default
      ]
      ++ optionals nodeMeta.microVmHost [
        microvm.nixosModules.host
      ]
      ++ optionals (nodeMeta.type == "microvm") [
        microvm.nixosModules.microvm
      ];
  }
