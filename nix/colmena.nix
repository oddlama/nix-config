{
  self,
  nixpkgs,
  ...
} @ inputs: let
  inherit
    (nixpkgs.lib)
    filterAttrs
    mapAttrs
    ;

  nixosNodes = filterAttrs (_: x: x.type == "nixos") self.hosts;
  nodes =
    mapAttrs
    (n: v: import ./generate-node.nix inputs n ({config = ../hosts/${n};} // v))
    nixosNodes;
in
  {
    meta = {
      description = "oddlama's colmena configuration";
      # Just a required dummy for colmena, overwritten on a per-node basis by nodeNixpkgs below.
      nixpkgs = self.pkgs.x86_64-linux;
      nodeNixpkgs = mapAttrs (_: node: node.pkgs) nodes;
      nodeSpecialArgs = mapAttrs (_: node: node.specialArgs) nodes;
    };
  }
  // mapAttrs (_: node: {inherit (node) imports;}) nodes
