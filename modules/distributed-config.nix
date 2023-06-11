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
    filter
    mdDoc
    mkOption
    types
    unique
    subtractLists
    ;

  inherit
    (extraLib)
    mergeToplevelConfigs
    ;
in {
  options.nodes = mkOption {
    type = types.attrsOf types.unspecified;
    default = {};
    description = mdDoc "Allows extending the configuration of other machines.";
  };

  config = let
    otherNodes = filter (n: n != nodeName) (attrNames colmenaNodes);
    foreignConfigs = map (n: colmenaNodes.${n}.config.nodes.${nodeName} or {}) otherNodes;
    toplevelAttrs = ["age" "networking" "systemd" "services"];
  in
    {
      assertions =
        map (n: {
          assertion = false;
          message = "Cannot extend configuration using nodes.${n} because the given node is not a registered or not a first-class nixos node (microvm's can't be extended right now).";
        })
        (subtractLists (attrNames colmenaNodes) (attrNames config.nodes));
    }
    // mergeToplevelConfigs toplevelAttrs foreignConfigs;
}
