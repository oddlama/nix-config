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
  nodeName: nodeMeta: let
    nodePath = nodeMeta.config or (../hosts + "/${nodeName}");
  in {
    inherit (nodeMeta) system;
    pkgs = self.pkgs.${nodeMeta.system};
    specialArgs = {
      inherit (nixpkgs) lib;
      inherit (self) extraLib nodes stateVersion;
      inherit inputs nodeName nodePath;
      secrets = self.secrets.content;
      nodeSecrets = self.secrets.content.nodes.${nodeName} or {};
      nixos-hardware = nixos-hardware.nixosModules;
      microvm = microvm.nixosModules;
    };
    imports = [
      nodePath # default module
      agenix.nixosModules.default
      agenix-rekey.nixosModules.default
      disko.nixosModules.disko
      home-manager.nixosModules.default
      impermanence.nixosModules.impermanence
      nixos-nftables-firewall.nixosModules.default
    ];
  }
