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
} @ inputs: nodeName: {configPath ? null, ...} @ nodeMeta: let
  inherit (nixpkgs.lib) optional pathIsDirectory;
in {
  inherit (nodeMeta) system;
  pkgs = self.pkgs.${nodeMeta.system};
  specialArgs = {
    inherit (nixpkgs) lib;
    inherit (self) extraLib nodes stateVersion colmenaNodes;
    inherit inputs nodeName;
    # Only set the nodePath if it is an actual directory
    nodePath =
      if builtins.isPath configPath && pathIsDirectory configPath
      then configPath
      else null;
    nixos-hardware = nixos-hardware.nixosModules;
    microvm = microvm.nixosModules;
  };
  imports =
    [
      agenix.nixosModules.default
      agenix-rekey.nixosModules.default
      disko.nixosModules.disko
      home-manager.nixosModules.default
      impermanence.nixosModules.impermanence
      nixos-nftables-firewall.nixosModules.default
    ]
    ++ optional (configPath != null) configPath;
}
