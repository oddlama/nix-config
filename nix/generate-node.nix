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
  pathOrNull = x:
    if builtins.isPath x
    then x
    else null;
in
  nodeName: nodeMeta: {
    inherit (nodeMeta) system;
    pkgs = self.pkgs.${nodeMeta.system};
    specialArgs = {
      inherit (nixpkgs) lib;
      inherit (self) extraLib nodes stateVersion;
      inherit inputs nodeName;
      nodePath = pathOrNull (nodeMeta.config or null);
      nixos-hardware = nixos-hardware.nixosModules;
      microvm = microvm.nixosModules;
    };
    imports = [
      (nodeMeta.config or {})
      agenix.nixosModules.default
      agenix-rekey.nixosModules.default
      disko.nixosModules.disko
      home-manager.nixosModules.default
      impermanence.nixosModules.impermanence
      nixos-nftables-firewall.nixosModules.default
    ];
  }
