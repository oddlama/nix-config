{
  self,
  colmena,
  home-manager,
  #impermanence,
  nixos-hardware,
  nixpkgs,
  ragenix,
  agenix-rekey,
  templates,
  ...
}:
with nixpkgs.lib; let
  nixosHosts = filterAttrs (_: x: x.type == "nixos") self.hosts;
  generateColmenaNode = hostName: _: {
    imports = [
      {
        # By default, set networking.hostName to the hostName
        networking.hostName = mkDefault hostName;
        # Define global flakes for this system
        nix.registry = {
          nixpkgs.flake = nixpkgs;
          p.flake = nixpkgs;
          pkgs.flake = nixpkgs;
          templates.flake = templates;
        };
      }
      (../hosts + "/${hostName}")
      home-manager.nixosModules.default
      #impermanence.nixosModules.default
      ragenix.nixosModules.age
      agenix-rekey.nixosModules.default
    ];
  };
in
  {
    meta = {
      description = "oddlama's colmena configuration";
      # Just a required dummy for colmena, overwritten on a per-node basis by nodeNixpkgs below.
      nixpkgs = self.pkgs.x86_64-linux;
      nodeNixpkgs = mapAttrs (hostName: {system, ...}: self.pkgs.${system}) nixosHosts;
      #nodeSpecialArgs = mapAttrs (hostName: { system, ... }: {}) nixosHosts;
      specialArgs = {
        inherit (nixpkgs) lib;
        nixos-hardware = nixos-hardware.nixosModules;
        #impermanence = impermanence.nixosModules;
      };
    };
  }
  // mapAttrs generateColmenaNode nixosHosts
