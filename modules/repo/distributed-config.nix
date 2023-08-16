{
  config,
  inputs,
  lib,
  options,
  nodes,
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
    allNodes = attrNames nodes;
    foreignConfigs = concatMap (n: nodes.${n}.config.nodes.${nodeName} or []) allNodes;
    mergeFromOthers = path:
      mkMerge (map
        (x: (getAttrFromPath path x))
        (lib.filter (x: (hasAttrByPath path x)) foreignConfigs));
  in {
    age.secrets = mergeFromOthers ["age" "secrets"];
    networking.providedDomains = mergeFromOthers ["networking" "providedDomains"];
    services.nginx.upstreams = mergeFromOthers ["services" "nginx" "upstreams"];
    services.nginx.virtualHosts = mergeFromOthers ["services" "nginx" "virtualHosts"];
    services.influxdb2.provision.ensureApiTokens = mergeFromOthers ["services" "influxdb2" "provision" "ensureApiTokens"];
  };
}
