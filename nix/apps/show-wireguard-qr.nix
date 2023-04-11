{
  self,
  pkgs,
  ...
}: let
  inherit
    (pkgs.lib)
    attrNames
    concatMap
    concatStringsSep
    escapeShellArg
    filter
    unique
    ;

  nodeNames = attrNames self.nodes;
  nodesWithNet = net: filter (n: builtins.hasAttr net self.nodes.${n}.config.extra.wireguard.networks) nodeNames;
  wireguardNetworks = unique (concatMap (n: attrNames self.nodes.${n}.config.extra.wireguard.networks) nodeNames);
  externalPeersForNet = net: concatMap (n: attrNames self.nodes.${n}.config.extra.wireguard.networks.${net}.externalPeers) (nodesWithNet net);
  externalPeers = concatMap (net: map (peer: {inherit net peer;}) (externalPeersForNet net)) wireguardNetworks;
in
  # TODO generate "classic" config and run qrencode
  pkgs.writeShellScript "show-wireguard-qr" ''
    set -euo pipefail
    echo ${escapeShellArg (concatStringsSep "\n" (map (x: "${x.net}.${x.peer}") externalPeers))} | fzf
  ''
