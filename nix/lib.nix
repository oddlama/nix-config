{
  self,
  nixpkgs,
  ...
}: let
  inherit
    (nixpkgs.lib)
    attrNames
    attrValues
    concatMap
    concatMapStrings
    concatStringsSep
    escapeShellArg
    filter
    flatten
    foldAttrs
    foldl'
    genAttrs
    head
    mapAttrs'
    mergeAttrs
    mkMerge
    nameValuePair
    optionalAttrs
    partition
    recursiveUpdate
    removeSuffix
    substring
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

  # Returns all elements in xs that occur at least twice
  duplicates = xs: let
    occurrences = countOccurrences xs;
  in
    unique (filter (x: occurrences.${x} > 1) xs);

  # Concatenates all given attrsets as if calling a // b in order.
  concatAttrs = foldl' mergeAttrs {};

  # True if the path or string starts with /
  isAbsolutePath = x: substring 0 1 x == "/";

  # Merges all given attributes from the given attrsets using mkMerge.
  # Useful to merge several top-level configs in a module.
  mergeToplevelConfigs = keys: attrs:
    genAttrs keys (attr: mkMerge (map (x: x.${attr} or {}) attrs));

  disko = {
    gpt = {
      partEfi = name: start: end: {
        inherit name start end;
        fs-type = "fat32";
        bootable = true;
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
        };
      };
      partSwap = name: start: end: {
        inherit name start end;
        fs-type = "linux-swap";
        content = {
          type = "swap";
          randomEncryption = true;
        };
      };
      partLuksZfs = name: start: end: {
        inherit start end;
        name = "enc-${name}";
        content = {
          type = "luks";
          name = "enc-${name}";
          extraOpenArgs = ["--allow-discards"];
          content = {
            type = "zfs";
            pool = name;
          };
        };
      };
    };
    zfs = {
      defaultZpoolOptions = {
        type = "zpool";
        mountRoot = "/mnt";
        rootFsOptions = {
          compression = "zstd";
          acltype = "posix";
          atime = "off";
          xattr = "sa";
          dnodesize = "auto";
          mountpoint = "none";
          canmount = "off";
          devices = "off";
        };
        options.ashift = "12";
      };

      unmountable = {type = "zfs_fs";};
      filesystem = mountpoint: {
        type = "zfs_fs";
        options = {
          canmount = "on";
          inherit mountpoint;
        };
        # Required to add dependencies for initrd
        inherit mountpoint;
      };
    };
  };

  rageMasterIdentityArgs = concatMapStrings (x: ''-i ${escapeShellArg x} '') self.secrets.masterIdentities;
  rageExtraEncryptionPubkeys =
    concatMapStrings (
      x:
        if isAbsolutePath x
        then ''-R ${escapeShellArg x} ''
        else ''-r ${escapeShellArg x} ''
    )
    self.secrets.extraEncryptionPubkeys;
  # The arguments required to de-/encrypt a secret in this repository
  rageDecryptArgs = "${rageMasterIdentityArgs}";
  rageEncryptArgs = "${rageMasterIdentityArgs} ${rageExtraEncryptionPubkeys}";

  # Wireguard related functions that are reused in several files of this flake
  wireguard = wgName: rec {
    # Get access to the networking lib by referring to one of the associated nodes.
    # Not ideal, but ok.
    inherit (self.nodes.${head associatedNodes}.config.lib) net;

    # Returns the given node's wireguard configuration of this network
    wgCfgOf = node: self.nodes.${node}.config.extra.wireguard.${wgName};

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

    peerPublicKeyFile = peerName: "secrets/wireguard/${wgName}/keys/${peerName}.pub";
    peerPublicKeyPath = peerName: "${../.}/" + peerPublicKeyFile peerName;

    peerPrivateKeyFile = peerName: "secrets/wireguard/${wgName}/keys/${peerName}.age";
    peerPrivateKeyPath = peerName: "${../.}/" + peerPrivateKeyFile peerName;
    peerPrivateKeySecret = peerName: "wireguard-${wgName}-priv-${peerName}";

    peerPresharedKeyFile = peerA: peerB: let
      inherit (sortedPeers peerA peerB) peer1 peer2;
    in "secrets/wireguard/${wgName}/psks/${peer1}+${peer2}.age";
    peerPresharedKeyPath = peerA: peerB: "${../.}/" + peerPresharedKeyFile peerA peerB;
    peerPresharedKeySecret = peerA: peerB: let
      inherit (sortedPeers peerA peerB) peer1 peer2;
    in "wireguard-${wgName}-psks-${peer1}+${peer2}";

    # All nodes that are part of this network
    associatedNodes =
      filter
      (n: builtins.hasAttr wgName self.nodes.${n}.config.extra.wireguard)
      (attrNames self.nodes);

    # Partition nodes by whether they are servers
    _associatedNodes_isServerPartition =
      partition
      (n: (wgCfgOf n).server.host != null)
      associatedNodes;

    associatedServerNodes = _associatedNodes_isServerPartition.right;
    associatedClientNodes = _associatedNodes_isServerPartition.wrong;

    # Maps all nodes that are part of this network to their addresses
    nodePeers = genAttrs associatedNodes (n: (wgCfgOf n).addresses);

    externalPeerName = p: "external-${p}";

    # Only peers that are defined as externalPeers on the given node.
    # Prepends "external-" to their name.
    externalPeersForNode = node:
      mapAttrs' (p: nameValuePair (externalPeerName p)) (wgCfgOf node).server.externalPeers;

    # All peers that are defined as externalPeers on any node.
    # Prepends "external-" to their name.
    allExternalPeers = concatAttrs (map externalPeersForNode associatedNodes);

    # All peers that are part of this network
    allPeers = nodePeers // allExternalPeers;

    # Concatenation of all external peer names names without any transformations.
    externalPeerNamesRaw = concatMap (n: attrNames (wgCfgOf n).server.externalPeers) associatedNodes;

    # A list of all occurring addresses.
    usedAddresses =
      concatMap (n: (wgCfgOf n).addresses) associatedNodes
      ++ flatten (concatMap (n: attrValues (wgCfgOf n).server.externalPeers) associatedNodes);

    # The cidrv4 and cidrv6 of the network spanned by all participating peer addresses.
    # This also takes into account any reserved address ranges that should be part of the network.
    networkAddresses =
      net.cidr.merge (usedAddresses
        ++ concatMap (n: (wgCfgOf n).server.reservedAddresses) associatedServerNodes);

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
      pkgs = self.pkgs.${system};
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
        AllowedIPs = ${concatStringsSep ", " snCfg.addresses}
        Endpoint = ${snCfg.server.host}:${toString snCfg.server.port}
        EOF
      '';
  };
}
