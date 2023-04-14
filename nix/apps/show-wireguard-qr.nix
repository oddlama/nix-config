{
  self,
  pkgs,
  ...
} @ inputs: let
  inherit
    (pkgs.lib)
    attrNames
    concatMap
    concatStringsSep
    escapeShellArg
    filter
    unique
    ;

  extraLib = import ../lib.nix inputs;

  nodeNames = attrNames self.nodes;
  wireguardNetworks = unique (concatMap (n: attrNames self.nodes.${n}.config.extra.wireguard) nodeNames);

  externalPeersForNet = wgName:
    map (peer: {inherit wgName peer;})
    (attrNames ((extraLib.wireguard wgName).externalPeers self.nodes));
  allExternalPeers = concatMap externalPeersForNet wireguardNetworks;
in
  # TODO generate "classic" config and run qrencode
  pkgs.writeShellScript "show-wireguard-qr" ''
    set -euo pipefail
    echo ${escapeShellArg (concatStringsSep "\n" (map (x: "${x.wgName}.${x.peer}") allExternalPeers))} | ${pkgs.fzf}/bin/fzf
  ''
