{
  self,
  nixpkgs,
  ...
} @ inputs: let
  inherit
    (nixpkgs.lib)
    filterAttrs
    flip
    mapAttrs
    ;

  nixosNodes = filterAttrs (_: x: x.type == "nixos") self.hosts;
  nodes = flip mapAttrs nixosNodes (name: hostCfg:
    import ./generate-node.nix inputs {
      inherit name;
      inherit (hostCfg) system;
      modules = [
        ../hosts/${name}
        {node.secretsDir = ../hosts/${name}/secrets;}
      ];
    });
in
  {
    meta = {
      description = "❄️";
      # Just a required dummy for colmena, overwritten on a per-node basis by nodeNixpkgs below.
      nixpkgs = self.pkgs.x86_64-linux;
      nodeNixpkgs = mapAttrs (_: node: node.pkgs) nodes;
      nodeSpecialArgs = mapAttrs (_: node: node.specialArgs) nodes;
    };
  }
  // mapAttrs (_: node: {inherit (node) imports;}) nodes
