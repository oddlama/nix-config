{
  config,
  inputs,
  lib,
  ...
}: let
  inherit
    (lib)
    attrNames
    concatMap
    elem
    mdDoc
    mkOption
    mkOptionType
    optionalAttrs
    types
    ;

  nodeName = config.repo.node.name;
in {
  options.nodes = mkOption {
    type = types.attrsOf (mkOptionType {
      name = "Toplevel NixOS config";
      merge = loc: map (x: x.value);
    });
    default = {};
    description = mdDoc "Allows extending the configuration of other machines.";
  };

  config = let
    allNodes = attrNames inputs.self.colmenaNodes;
    isColmenaNode = elem nodeName allNodes;
    foreignConfigs = concatMap (n: inputs.self.colmenaNodes.${n}.config.nodes.${nodeName} or []) allNodes;
    toplevelAttrs = ["age" "networking" "systemd" "services"];
  in
    optionalAttrs isColmenaNode (config.lib.misc.mergeToplevelConfigs toplevelAttrs (
      foreignConfigs
      # Also allow extending ourselves, in case some attributes from depenent
      # configurations such as containers or microvms are merged to the host
      ++ [config.nodes.${nodeName} or {}]
    ));
}
