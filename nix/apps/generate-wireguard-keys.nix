{
  self,
  pkgs,
  ...
} @ inputs: let
  inherit
    (pkgs.lib)
    attrNames
    concatMap
    concatMapStrings
    concatStringsSep
    escapeShellArg
    filter
    optionalString
    removeSuffix
    substring
    unique
    ;

  inherit (self.extraLib) rageEncryptArgs;

  nodeNames = attrNames self.nodes;
  wireguardNetworks = unique (concatMap (n: attrNames self.nodes.${n}.config.extra.wireguard) nodeNames);

  generateNetworkKeys = wgName: let
    inherit
      (self.extraLib.wireguard wgName)
      allPeers
      associatedNodes
      associatedServerNodes
      associatedClientNodes
      externalPeersForNode
      peerPresharedKeyFile
      peerPrivateKeyFile
      peerPublicKeyFile
      sortedPeers
      ;

    # Every peer needs a private and public key.
    generatePeerKeys = peerName: let
      keyBasename = escapeShellArg ("./" + removeSuffix ".pub" (peerPublicKeyFile peerName));
      pubkeyFile = escapeShellArg ("./" + peerPublicKeyFile peerName);
      privkeyFile = escapeShellArg ("./" + peerPrivateKeyFile peerName);
    in ''
      if [[ ! -e ${privkeyFile} ]] || [[ ! -e ${pubkeyFile} ]]; then
        mkdir -p $(dirname ${privkeyFile})
        echo "Generating [34m"${keyBasename}".{[31mage[34m,[32mpub[34m}[m"
        privkey=$(${pkgs.wireguard-tools}/bin/wg genkey)
        echo "$privkey" | ${pkgs.wireguard-tools}/bin/wg pubkey > ${pubkeyFile}
        ${pkgs.rage}/bin/rage -e ${rageEncryptArgs} <<< "$privkey" > ${privkeyFile} \
          || { echo "[1;31merror:[m Failed to encrypt wireguard private key for peer ${peerName} on network ${wgName}!" >&2; exit 1; }
      fi
    '';

    # Generates the psk for peer1 and peer2.
    generatePeerPsk = {
      peer1,
      peer2,
    }: let
      pskFile = escapeShellArg ("./" + peerPresharedKeyFile peer1 peer2);
    in ''
      if [[ ! -e ${pskFile} ]]; then
        mkdir -p $(dirname ${pskFile})
        echo "Generating [33m"${pskFile}"[m"
        psk=$(${pkgs.wireguard-tools}/bin/wg genpsk)
        ${pkgs.rage}/bin/rage -e ${rageEncryptArgs} <<< "$psk" > ${pskFile} \
          || { echo "[1;31merror:[m Failed to encrypt wireguard psk for peers ${peer1} and ${peer2} on network ${wgName}!" >&2; exit 1; }
      fi
    '';

    # This generates all psks for each combination of peers given.
    # xs is a list of peers and fys a function that generates a list of peers
    # for any given x.
    psksForPeerCombinations = xs: fys: map generatePeerPsk (unique (concatMap (x: map (sortedPeers x) (fys x)) xs));
  in
    ["echo ==== ${wgName} ===="]
    ++ map generatePeerKeys (attrNames allPeers)
    # All server-nodes need a psk for each other, but not reflexive.
    ++ psksForPeerCombinations associatedServerNodes (n: filter (x: x != n) associatedServerNodes)
    # Each server-node need a psk for all client nodes
    ++ psksForPeerCombinations associatedServerNodes (_: associatedClientNodes)
    # Each server-node need a psk for all their external peers
    ++ psksForPeerCombinations associatedServerNodes (n: attrNames (externalPeersForNode n));
in
  pkgs.writeShellScript "generate-wireguard-keys" ''
    set -euo pipefail
    ${concatStringsSep "\n" (concatMap generateNetworkKeys wireguardNetworks)}
  ''
