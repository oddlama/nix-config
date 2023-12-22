{
  config,
  lib,
  nodes,
  ...
}: let
  inherit
    (lib)
    attrNames
    concatMap
    getAttrFromPath
    mkOption
    mkOptionType
    mkMerge
    hasAttrByPath
    types
    ;

  nodeName = config.node.name;
in {
  # TODO expose exactly what we can configure! not everything
  options.nodes = mkOption {
    default = {};
    description = "Allows extending the configuration of other machines.";
    type = types.attrsOf (mkOptionType {
      name = "Toplevel NixOS config";
      merge = _loc: map (x: x.value);
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
    services.influxdb2.provision.organizations = mergeFromOthers ["services" "influxdb2" "provision" "organizations"];
    services.kanidm.provision.groups = mergeFromOthers ["services" "kanidm" "provision" "groups"];
    services.kanidm.provision.systems.oauth2 = mergeFromOthers ["services" "kanidm" "provision" "systems" "oauth2"];
  };
}
