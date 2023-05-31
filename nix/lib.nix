{
  self,
  nixpkgs,
  ...
}: let
  inherit
    (nixpkgs.lib)
    all
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
    head
    isAttrs
    mapAttrs'
    mergeAttrs
    mkMerge
    mkOptionType
    nameValuePair
    optionalAttrs
    partition
    recursiveUpdate
    removeSuffix
    showOption
    stringToCharacters
    substring
    unique
    ;
in rec {
  types = rec {
    # Checks whether the value is a lazy value without causing
    # it's value to be evaluated
    isLazyValue = x: isAttrs x && x ? _lazyValue;
    # Constructs a lazy value holding the given value.
    lazyValue = value: {_lazyValue = value;};

    # Represents a lazy value of the given type, which
    # holds the actual value as an attrset like { _lazyValue = <actual value>; }.
    # This allows the option to be defined and filtered from a defintion
    # list without evaluating the value.
    lazyValueOf = type:
      mkOptionType rec {
        name = "lazyValueOf ${type.name}";
        inherit (type) description descriptionClass emptyValue getSubOptions getSubModules;
        check = isLazyValue;
        merge = loc: defs:
          assert assertMsg
          (all (x: type.check x._lazyValue) defs)
          "The option `${showOption loc}` is defined with a lazy value holding an invalid type";
            nixpkgs.lib.types.mergeOneOption loc defs;
        substSubModules = m: nixpkgs.lib.types.uniq (type.substSubModules m);
        functor = (nixpkgs.lib.types.defaultFunctor name) // {wrapped = type;};
        nestedTypes.elemType = type;
      };

    # Represents a value or lazy value of the given type that will
    # automatically be coerced to the given type when merged.
    lazyOf = type: nixpkgs.lib.types.coercedTo (lazyValueOf type) (x: x._lazyValue) type;
  };

  # Counts how often each element occurrs in xs
  countOccurrences = let
    addOrUpdate = acc: x:
      if builtins.hasAttr x acc
      then acc // {${x} = acc.${x} + 1;}
      else acc // {${x} = 1;};
  in
    foldl' addOrUpdate {};

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

  # Calculates base^exp, but careful, this overflows for results > 2^62
  pow = base: exp: foldl' (a: x: x * a) 1 (genList (_: base) exp);

  # Converts the given hex string to an integer. Only reliable for inputs in [0, 2^63),
  # after that the sign bit will overflow.
  hexToDec = v: let
    literalValues = {
      "0" = 0;
      "1" = 1;
      "2" = 2;
      "3" = 3;
      "4" = 4;
      "5" = 5;
      "6" = 6;
      "7" = 7;
      "8" = 8;
      "9" = 9;
      "a" = 10;
      "b" = 11;
      "c" = 12;
      "d" = 13;
      "e" = 14;
      "f" = 15;
      "A" = 10;
      "B" = 11;
      "C" = 12;
      "D" = 13;
      "E" = 14;
      "F" = 15;
    };
  in
    foldl' (acc: x: acc * 16 + literalValues.${x}) 0 (stringToCharacters v);

  disko = {
    gpt = {
      partGrub = name: start: end: {
        inherit name start end;
        part-type = "primary";
        flags = ["bios_grub"];
      };
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

  rageMasterIdentityArgs = concatMapStrings (x: ''-i ${escapeShellArg x} '') self.secretsConfig.masterIdentities;
  rageExtraEncryptionPubkeys =
    concatMapStrings (
      x:
        if isAbsolutePath x
        then ''-R ${escapeShellArg x} ''
        else ''-r ${escapeShellArg x} ''
    )
    self.secretsConfig.extraEncryptionPubkeys;
  # The arguments required to de-/encrypt a secret in this repository
  rageDecryptArgs = "${rageMasterIdentityArgs}";
  rageEncryptArgs = "${rageMasterIdentityArgs} ${rageExtraEncryptionPubkeys}";

  # TODO merge this into a _meta readonly option in the wireguard module
  # Wireguard related functions that are reused in several files of this flake
  wireguard = wgName: rec {
    # Get access to the networking lib by referring to one of the participating nodes.
    # Not ideal, but ok.
    inherit (self.nodes.${head participatingNodes}.config.lib) net;

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
    participatingNodes =
      filter
      (n: builtins.hasAttr wgName self.nodes.${n}.config.extra.wireguard)
      (attrNames self.nodes);

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
        filter (x: !types.isLazyValue x)
        (concatLists
          (self.nodes.${n}.options.extra.wireguard.type.functor.wrapped.getSubOptions (wgCfgOf n)).addresses.definitions))
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
        AllowedIPs = ${concatStringsSep ", " networkCidrs}
        Endpoint = ${snCfg.server.host}:${toString snCfg.server.port}
        PersistentKeepalive = 25
        EOF
      '';
  };
}
