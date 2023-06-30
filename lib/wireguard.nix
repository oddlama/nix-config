inputs: wgName: let
  inherit
    (inputs.nixpkgs.lib)
    all
    any
    assertMsg
    attrNames
    attrValues
    concatLists
    concatMap
    concatMapStrings
    concatStringsSep
    elem
    escapeShellArg
    filter
    flatten
    flip
    foldAttrs
    foldl'
    genAttrs
    genList
    hasInfix
    head
    isAttrs
    mapAttrs'
    mergeAttrs
    min
    mkMerge
    mkOptionType
    nameValuePair
    optionalAttrs
    partition
    range
    recursiveUpdate
    removeSuffix
    reverseList
    showOption
    splitString
    stringToCharacters
    substring
    types
    unique
    warnIf
    ;

  net = import ./net.nix inputs;
  misc = import ./misc.nix inputs;
  inherit
    (import ./types.nix inputs)
    isLazyValue
    ;

  inherit
    (misc)
    concatAttrs
    ;

  inherit
    (misc.secrets)
    rageDecryptArgs
    ;

  inherit (inputs.self) nodes;
in rec {
  # Returns the given node's wireguard configuration of this network
  wgCfgOf = node: nodes.${node}.config.meta.wireguard.${wgName};

  sortedPeers = peerA: peerB:
    if peerA < peerB
    then {
      peer1 = peerA;
      peer2 = peerB;
    }
    else {
      peer1 = peerB;
      peer2 = peerA;
    };

  peerPublicKeyFile = peerName: "/secrets/wireguard/${wgName}/keys/${peerName}.pub";
  peerPublicKeyPath = peerName: inputs.self.outPath + peerPublicKeyFile peerName;

  peerPrivateKeyFile = peerName: "/secrets/wireguard/${wgName}/keys/${peerName}.age";
  peerPrivateKeyPath = peerName: inputs.self.outPath + peerPrivateKeyFile peerName;
  peerPrivateKeySecret = peerName: "wireguard-${wgName}-priv-${peerName}";

  peerPresharedKeyFile = peerA: peerB: let
    inherit (sortedPeers peerA peerB) peer1 peer2;
  in "/secrets/wireguard/${wgName}/psks/${peer1}+${peer2}.age";
  peerPresharedKeyPath = peerA: peerB: inputs.self.outPath + peerPresharedKeyFile peerA peerB;
  peerPresharedKeySecret = peerA: peerB: let
    inherit (sortedPeers peerA peerB) peer1 peer2;
  in "wireguard-${wgName}-psks-${peer1}+${peer2}";

  # All nodes that are part of this network
  participatingNodes =
    filter
    (n: builtins.hasAttr wgName nodes.${n}.config.meta.wireguard)
    (attrNames nodes);

  # Partition nodes by whether they are servers
  _participatingNodes_isServerPartition =
    partition
    (n: (wgCfgOf n).server.host != null)
    participatingNodes;

  participatingServerNodes = _participatingNodes_isServerPartition.right;
  participatingClientNodes = _participatingNodes_isServerPartition.wrong;

  # Maps all nodes that are part of this network to their addresses
  nodePeers = genAttrs participatingNodes (n: (wgCfgOf n).addresses);

  externalPeerName = p: "external-${p}";

  # Only peers that are defined as externalPeers on the given node.
  # Prepends "external-" to their name.
  externalPeersForNode = node:
    mapAttrs' (p: nameValuePair (externalPeerName p)) (wgCfgOf node).server.externalPeers;

  # All peers that are defined as externalPeers on any node.
  # Prepends "external-" to their name.
  allExternalPeers = concatAttrs (map externalPeersForNode participatingNodes);

  # All peers that are part of this network
  allPeers = nodePeers // allExternalPeers;

  # Concatenation of all external peer names names without any transformations.
  externalPeerNamesRaw = concatMap (n: attrNames (wgCfgOf n).server.externalPeers) participatingNodes;

  # A list of all occurring addresses.
  usedAddresses =
    concatMap (n: (wgCfgOf n).addresses) participatingNodes
    ++ flatten (concatMap (n: attrValues (wgCfgOf n).server.externalPeers) participatingNodes);

  # A list of all occurring addresses, but only includes addresses that
  # are not assigned automatically.
  explicitlyUsedAddresses =
    flip concatMap participatingNodes
    (n:
      filter (x: !isLazyValue x)
      (concatLists
        (nodes.${n}.options.meta.wireguard.type.functor.wrapped.getSubOptions (wgCfgOf n)).addresses.definitions))
    ++ flatten (concatMap (n: attrValues (wgCfgOf n).server.externalPeers) participatingNodes);

  # The cidrv4 and cidrv6 of the network spanned by all participating peer addresses.
  # This also takes into account any reserved address ranges that should be part of the network.
  networkAddresses =
    net.cidr.merge (usedAddresses
      ++ concatMap (n: (wgCfgOf n).server.reservedAddresses) participatingServerNodes);

  # The network spanning cidr addresses. The respective cidrv4 and cirdv6 are only
  # included if they exist.
  networkCidrs = filter (x: x != null) (attrValues networkAddresses);

  # The cidrv4 and cidrv6 of the network spanned by all reserved addresses only.
  # Used to determine automatically assigned addresses first.
  spannedReservedNetwork =
    net.cidr.merge (concatMap (n: (wgCfgOf n).server.reservedAddresses) participatingServerNodes);

  # Assigns an ipv4 address from spannedReservedNetwork.cidrv4
  # to each participant that has not explicitly specified an ipv4 address.
  assignedIpv4Addresses = assert assertMsg
  (spannedReservedNetwork.cidrv4 != null)
  "Wireguard network '${wgName}': At least one participating node must reserve a cidrv4 address via `reservedAddresses` so that ipv4 addresses can be assigned automatically from that network.";
    net.cidr.assignIps
    spannedReservedNetwork.cidrv4
    # Don't assign any addresses that are explicitly configured on other hosts
    (filter (x: net.cidr.contains x spannedReservedNetwork.cidrv4) (filter net.ip.isv4 explicitlyUsedAddresses))
    participatingNodes;

  # Assigns an ipv4 address from spannedReservedNetwork.cidrv4
  # to each participant that has not explicitly specified an ipv4 address.
  assignedIpv6Addresses = assert assertMsg
  (spannedReservedNetwork.cidrv6 != null)
  "Wireguard network '${wgName}': At least one participating node must reserve a cidrv6 address via `reservedAddresses` so that ipv4 addresses can be assigned automatically from that network.";
    net.cidr.assignIps
    spannedReservedNetwork.cidrv6
    # Don't assign any addresses that are explicitly configured on other hosts
    (filter (x: net.cidr.contains x spannedReservedNetwork.cidrv6) (filter net.ip.isv6 explicitlyUsedAddresses))
    participatingNodes;

  # Appends / replaces the correct cidr length to the argument,
  # so that the resulting address is in the cidr.
  toNetworkAddr = addr: let
    relevantNetworkAddr =
      if net.ip.isv6 addr
      then networkAddresses.cidrv6
      else networkAddresses.cidrv4;
  in "${net.cidr.ip addr}/${toString (net.cidr.length relevantNetworkAddr)}";

  # Creates a script that when executed outputs a wg-quick compatible configuration
  # file for use with external peers. This is a script so we can access secrets without
  # storing them in the nix-store.
  wgQuickConfigScript = system: serverNode: extPeer: let
    pkgs = inputs.self.pkgs.${system};
    snCfg = wgCfgOf serverNode;
    peerName = externalPeerName extPeer;
    addresses = map toNetworkAddr snCfg.server.externalPeers.${extPeer};
  in
    pkgs.writeShellScript "create-wg-conf-${wgName}-${serverNode}-${extPeer}" ''
      privKey=$(${pkgs.rage}/bin/rage -d ${rageDecryptArgs} ${escapeShellArg (peerPrivateKeyPath peerName)}) \
        || { echo "[1;31merror:[m Failed to decrypt!" >&2; exit 1; }
      serverPsk=$(${pkgs.rage}/bin/rage -d ${rageDecryptArgs} ${escapeShellArg (peerPresharedKeyPath serverNode peerName)}) \
        || { echo "[1;31merror:[m Failed to decrypt!" >&2; exit 1; }

      cat <<EOF
      [Interface]
      Address = ${concatStringsSep ", " addresses}
      PrivateKey = $privKey

      [Peer]
      PublicKey = ${removeSuffix "\n" (builtins.readFile (peerPublicKeyPath serverNode))}
      PresharedKey = $serverPsk
      AllowedIPs = ${concatStringsSep ", " networkCidrs}
      Endpoint = ${snCfg.server.host}:${toString snCfg.server.port}
      PersistentKeepalive = 25
      EOF
    '';
}
