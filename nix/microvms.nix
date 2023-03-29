{
  self,
  nixpkgs,
  ...
} @ inputs: let
  inherit
    (nixpkgs.lib)
    filterAttrs
    mapAttrs
    nixosSystem
    ;

  microvmNodes = filterAttrs (_: x: x.type == "microvm") self.hosts;
  nodes = mapAttrs (import ./generate-node.nix inputs) microvmNodes;
  generateMicrovmNode = nodeName: _:
    nixosSystem {
      inherit (nodes.${nodeName}) system pkgs specialArgs;
      modules = nodes.${nodeName}.imports;
    };
in
  mapAttrs generateMicrovmNode nodes
