{nixpkgs, ...}: let
  inherit
    (nixpkgs.lib)
    attrNames
    attrValues
    concatMap
    filter
    flatten
    foldl'
    genAttrs
    mapAttrs'
    mergeAttrs
    nameValuePair
    unique
    ;
in rec {
  # Counts how often each element occurrs in xs
  countOccurrences = xs: let
    addOrUpdate = acc: x:
      if builtins.hasAttr x acc
      then acc // {${x} = acc.${x} + 1;}
      else acc // {${x} = 1;};
  in
    foldl' addOrUpdate {} xs;

  # Returns all elements in xs that occur at least once
  duplicates = xs: let
    occurrences = countOccurrences xs;
  in
    unique (filter (x: occurrences.${x} > 1) xs);

  # Concatenates all given attrsets as if calling a // b in order.
  concatAttrs = foldl' mergeAttrs {};

  # Wireguard related functions that are reused in several files of this flake
  wireguard = wgName: rec {
    _sortedPeers = peerA: peerB:
      if peerA < peerB
      then {
        peer1 = peerA;
        peer2 = peerB;
      }
      else {
        peer1 = peerB;
        peer2 = peerA;
      };

    peerPublicKeyFile = peerName: "secrets/wireguard/${wgName}/keys/${peerName}.pub";
    peerPublicKeyPath = peerName: "${../.}/" + peerPublicKeyFile peerName;

    peerPrivateKeyFile = peerName: "secrets/wireguard/${wgName}/keys/${peerName}.age";
    peerPrivateKeyPath = peerName: "${../.}/" + peerPrivateKeyFile peerName;
    peerPrivateKeySecret = peerName: "wireguard-${wgName}-priv-${peerName}";

    peerPresharedKeyFile = peerA: peerB: let
      inherit (_sortedPeers peerA peerB) peer1 peer2;
    in "secrets/wireguard/${wgName}/psks/${peer1}+${peer2}.age";
    peerPresharedKeyPath = peerA: peerB: "${../.}/" + peerPresharedKeyFile peerA peerB;
    peerPresharedKeySecret = peerA: peerB: let
      inherit (_sortedPeers peerA peerB) peer1 peer2;
    in "wireguard-${wgName}-psks-${peer1}+${peer2}";

    # All nodes that are part of this network
    associatedNodes = nodes: filter (n: builtins.hasAttr wgName nodes.${n}.config.extra.wireguard) (attrNames nodes);
    nodePeers = nodes: genAttrs (associatedNodes nodes) (n: nodes.${n}.config.extra.wireguard.${wgName}.address);
    # All peers that are defined as externalPeers on any node.
    # Prepends "external-" to their name.
    externalPeers = nodes:
      concatAttrs (
        map (n: mapAttrs' (extPeerName: nameValuePair "external-${extPeerName}") nodes.${n}.config.extra.wireguard.${wgName}.externalPeers)
        (associatedNodes nodes)
      );
    # Concatenation of all external peer names names without any transformations.
    externalPeerNamesRaw = nodes: concatMap (n: attrNames nodes.${n}.config.extra.wireguard.${wgName}.externalPeers) (associatedNodes nodes);
    # A list of all occurring addresses.
    usedAddresses = nodes: let
      nodesWithNet = associatedNodes nodes;
    in
      concatMap (n: nodes.${n}.config.extra.wireguard.${wgName}.address) nodesWithNet
      ++ flatten (concatMap (n: attrValues nodes.${n}.config.extra.wireguard.${wgName}.externalPeers) nodesWithNet);

    allPeers = nodes: nodePeers nodes // externalPeers nodes;
  };
}
