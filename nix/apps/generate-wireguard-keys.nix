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
    removeSuffix
    substring
    unique
    ;

  extraLib = import ../lib.nix inputs;
  isAbsolutePath = x: substring 0 1 x == "/";
  masterIdentityArgs = concatMapStrings (x: ''-i ${escapeShellArg x} '') self.secrets.masterIdentities;
  extraEncryptionPubkeys =
    concatMapStrings (
      x:
        if isAbsolutePath x
        then ''-R ${escapeShellArg x} ''
        else ''-r ${escapeShellArg x} ''
    )
    self.secrets.extraEncryptionPubkeys;

  nodeNames = attrNames self.nodes;
  wireguardNetworks = unique (concatMap (n: attrNames self.nodes.${n}.config.extra.wireguard) nodeNames);

  generateNetworkKeys = wgName: let
    inherit
      (extraLib.wireguard wgName)
      allPeers
      associatedNodes
      peerPresharedKeyFile
      peerPrivateKeyFile
      peerPublicKeyFile
      ;

    nodesWithNet = associatedNodes self.nodes;
    peers = attrNames (allPeers self.nodes);

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
        ${pkgs.rage}/bin/rage -e ${masterIdentityArgs} ${extraEncryptionPubkeys} <<< "$privkey" > ${privkeyFile} \
          || { echo "[1;31merror:[m Failed to encrypt wireguard private key for peer ${peerName} on network ${wgName}!" >&2; exit 1; }
      fi
    '';

    generatePeerPsks = nodePeerName:
      map (peerName: let
        pskFile = escapeShellArg ("./" + peerPresharedKeyFile nodePeerName peerName);
      in ''
        if [[ ! -e ${pskFile} ]]; then
          mkdir -p $(dirname ${pskFile})
          echo "Generating [33m"${pskFile}"[m"
          psk=$(${pkgs.wireguard-tools}/bin/wg genpsk)
          ${pkgs.rage}/bin/rage -e ${masterIdentityArgs} ${extraEncryptionPubkeys} <<< "$psk" > ${pskFile} \
            || { echo "[1;31merror:[m Failed to encrypt wireguard psk for peers ${nodePeerName} and ${peerName} on network ${wgName}!" >&2; exit 1; }
        fi
      '') (filter (x: x != nodePeerName) peers);
  in
    ["echo ==== ${wgName} ===="]
    ++ map generatePeerKeys peers
    ++ concatMap generatePeerPsks nodesWithNet;
in
  pkgs.writeShellScript "generate-wireguard-keys" ''
    set -euo pipefail
    ${concatStringsSep "\n" (concatMap generateNetworkKeys wireguardNetworks)}
  ''
