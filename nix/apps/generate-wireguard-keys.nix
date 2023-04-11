{
  self,
  pkgs,
  ...
}: let
  inherit
    (pkgs.lib)
    attrNames
    concatMap
    concatMapStrings
    concatStringsSep
    escapeShellArg
    filter
    substring
    unique
    ;

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

  nodeNames = attrNames self.nodes;
  nodesWithNet = wgName: filter (n: builtins.hasAttr wgName self.nodes.${n}.config.extra.wireguard.networks) nodeNames;
  wireguardNetworks = unique (concatMap (n: attrNames self.nodes.${n}.config.extra.wireguard.networks) nodeNames);
  externalPeersForNet = wgName: concatMap (n: attrNames self.nodes.${n}.config.extra.wireguard.networks.${wgName}.externalPeers) (nodesWithNet wgName);

  externalPeers = wgName: concatMap (n: attrNames self.nodes.${n}.config.extra.wireguard.networks.${wgName}.externalPeers) (nodesWithNet wgName);
  peers = wgName: nodesWithNet wgName ++ externalPeers wgName;

  peerKeyBasename = wgName: peerName: "./secrets/wireguard/${wgName}/keys/${peerName}";
  generatePeerKeys = wgName: peerName: let
    keyBasename = peerKeyBasename wgName peerName;
    privkeyFile = escapeShellArg "${keyBasename}.age";
    pubkeyFile = escapeShellArg "${keyBasename}.pub";
  in ''
    if [[ ! -e ${privkeyFile} ]] || [[ ! -e ${pubkeyFile} ]]; then
      mkdir -p $(dirname ${privkeyFile})
      echo "Generating [34m"${escapeShellArg keyBasename}".{[31mage[34m,[32mpub[34m}[m"
      privkey=$(${pkgs.wireguard-tools}/bin/wg genkey)
      echo "$privkey" | ${pkgs.wireguard-tools}/bin/wg pubkey > ${pubkeyFile}
      ${pkgs.rage}/bin/rage -e ${masterIdentityArgs} ${extraEncryptionPubkeys} <<< "$privkey" > ${pubkeyFile} \
        || { echo "[1;31merror:[m Failed to encrypt wireguard private key for peer ${peerName} on network ${wgName}!" >&2; exit 1; }
    fi
  '';

  generatePeerPsks = wgName: nodePeerName:
    concatStringsSep "\n" (map (peerName: let
      inherit (sortedPeers nodePeerName peerName) peer1 peer2;
      pskFile = "./secrets/wireguard/${wgName}/psks/${peer1}-${peer2}.age";
    in ''
      if [[ ! -e ${pskFile} ]]; then
        mkdir -p $(dirname ${pskFile})
        echo "Generating [33m"${pskFile}"[m"
        psk=$(${pkgs.wireguard-tools}/bin/wg genpsk)
        ${pkgs.rage}/bin/rage -e ${masterIdentityArgs} ${extraEncryptionPubkeys} <<< "$psk" > ${pskFile} \
          || { echo "[1;31merror:[m Failed to encrypt wireguard psk for peers ${peer1} and ${peer2} on network ${wgName}!" >&2; exit 1; }
      fi
    '') (filter (x: x != nodePeerName) (peers wgName)));
in
  pkgs.writeShellScript "generate-wireguard-keys" ''
    set -euo pipefail
    ${concatStringsSep "\n" (concatMap (wgName: map (generatePeerKeys wgName) (peers wgName)) wireguardNetworks)}
    ${concatStringsSep "\n" (concatMap (wgName: map (generatePeerPsks wgName) (nodesWithNet wgName)) wireguardNetworks)}
  ''
