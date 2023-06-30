{
  config,
  inputs,
  lib,
  options,
  ...
}: let
  inherit
    (lib)
    attrNames
    concatMap
    elem
    foldl'
    getAttrFromPath
    mdDoc
    mkIf
    mkOption
    mkOptionType
    mkMerge
    optionalAttrs
    recursiveUpdate
    hasAttrByPath
    setAttrByPath
    types
    ;

  nodeName = config.node.name;
in {
  options.nodes = mkOption {
    default = {};
    description = mdDoc "Allows extending the configuration of other machines.";
    type = types.attrsOf (mkOptionType {
      name = "Toplevel NixOS config";
      merge = loc: map (x: x.value);
    });
  };

  config = let
    allNodes = attrNames inputs.self.colmenaNodes;
    isColmenaNode = elem nodeName allNodes;
    foreignConfigs = concatMap (n: inputs.self.colmenaNodes.${n}.config.nodes.${nodeName} or []) allNodes;
    relevantConfigs = foreignConfigs ++ [config.nodes.${nodeName} or {}];
    mergeFromOthers = path:
      mkMerge (map
        (x: mkIf (hasAttrByPath path x) (getAttrFromPath path x))
        relevantConfigs);
    pathsToMerge = [
      ["age" "secrets"]
      ["networking" "providedDomains"]
      ["services" "nginx" "upstreams"]
      ["services" "nginx" "virtualHosts"]
    ];
  in
    mkIf isColmenaNode (foldl'
      (acc: path: recursiveUpdate acc (setAttrByPath path (mergeFromOthers path)))
      {}
      pathsToMerge);
}
