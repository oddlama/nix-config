{
  config,
  extraLib,
  lib,
  nodeName,
  colmenaNodes,
  ...
}: let
  inherit
    (lib)
    attrNames
    concatMap
    elem
    filter
    mdDoc
    mkOption
    mkOptionType
    optionalAttrs
    types
    ;

  inherit
    (extraLib)
    mergeToplevelConfigs
    ;
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
    allNodes = attrNames colmenaNodes;
    isColmenaNode = elem nodeName allNodes;
    foreignConfigs = concatMap (n: colmenaNodes.${n}.config.nodes.${nodeName} or []) allNodes;
    toplevelAttrs = ["age" "proxiedDomains" "networking" "systemd" "services"];
  in
    optionalAttrs isColmenaNode (mergeToplevelConfigs toplevelAttrs (
      foreignConfigs
      # Also allow extending ourselves, in case some attributes from depenent
      # configurations such as containers or microvms are merged to the host
      ++ [config.nodes.${nodeName} or {}]
    ));
}
