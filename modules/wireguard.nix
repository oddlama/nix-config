{
  config,
  lib,
  extraLib,
  pkgs,
  nodes,
  nodeName,
  ...
}: let
  inherit
    (lib)
    any
    attrNames
    attrValues
    concatMap
    concatMapStrings
    concatStringsSep
    filter
    flatten
    foldl'
    genAttrs
    head
    mapAttrs'
    mapAttrsToList
    mdDoc
    mergeAttrs
    mkIf
    mkOption
    nameValuePair
    optional
    recursiveUpdate
    splitString
    types
    ;

  inherit (extraLib) duplicates;

  cfg = config.extra.wireguard;

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

  configForNetwork = wgName: wg: let
    peerPublicKey = peerName: builtins.readFile (../secrets/wireguard + "/${wgName}/keys/${peerName}.pub");
    peerPrivateKeyFile = peerName: ../secrets/wireguard + "/${wgName}/keys/${peerName}.age";
    peerPrivateKeySecret = peerName: "wireguard-${wgName}-priv-${peerName}";

    peerPresharedKeyFile = peerA: peerB: let
      inherit (sortedPeers peerA peerB) peer1 peer2;
    in
      ../secrets/wireguard + "/${wgName}/psks/${peer1}-${peer2}.age";

    peerPresharedKeySecret = peerA: peerB: let
      inherit (sortedPeers peerA peerB) peer1 peer2;
    in "wireguard-${wgName}-psks-${peer1}-${peer2}";

    # All peers that are other nodes
    nodesWithThisNetwork = filter (n: builtins.hasAttr wgName nodes.${n}.config.extra.wireguard.networks) (attrNames nodes);
    nodePeers = genAttrs (filter (n: n != nodeName) nodesWithThisNetwork) (n: nodes.${n}.config.extra.wireguard.networks.${wgName}.address);
    # All peers that are defined as externalPeers on any node. Also prepends "external-" to their name.
    externalPeers = foldl' recursiveUpdate {} (
      map (n: mapAttrs' (extPeerName: nameValuePair "external-${extPeerName}") nodes.${n}.config.extra.wireguard.networks.${wgName}.externalPeers)
      nodesWithThisNetwork
    );

    peers = nodePeers // externalPeers;

    peerDefinition = peerName: peerAllowedIPs: {
      wireguardPeerConfig =
        {
          PublicKey = peerPublicKey wgName peerName;
          PresharedKeyFile = config.rekey.secrets.${peerPresharedKeySecret wgName nodeName peerName}.path;
          AllowedIPs = peerAllowedIPs;
        }
        // optional wg.listen {
          PersistentKeepalive = 25;
        };
    };
  in {
    inherit nodesWithThisNetwork wgName;

    secrets =
      foldl' mergeAttrs {
        ${peerPrivateKeySecret nodeName}.file = peerPrivateKeyFile nodeName;
      } (map (peerName: {
        ${peerPresharedKeySecret nodeName peerName}.file = peerPresharedKeyFile nodeName peerName;
      }) (attrNames peers));

    netdevs."${wg.priority}-${wgName}" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = "${wgName}";
        Description = "Wireguard network ${wgName}";
      };
      wireguardConfig = {
        PrivateKeyFile = config.rekey.secrets.${peerPrivateKeySecret nodeName}.path;
        ListenPort = wg.listenPort;
      };
      wireguardPeers = mapAttrsToList peerDefinition peers;
    };

    networks."${wg.priority}-${wgName}" = {
      matchConfig.Name = wgName;
      networkConfig.Address = wg.address;
    };
  };
in {
  options = {
    extra.wireguard.networks = mkOption {
      default = {};
      description = "Configures wireguard networks via systemd-networkd.";
      type = types.attrsOf (types.submodule {
        options = {
          address = mkOption {
            type = types.listOf types.str;
            description = mdDoc ''
              The addresses to configure for this interface. Will automatically be added
              as this peer's allowed addresses to all other peers.
            '';
          };

          listen = mkOption {
            type = types.bool;
            default = false;
            description = mdDoc ''
              Enables listening for incoming wireguard connections.
              This also causes all other peers to include this as an endpoint in their configuration.
            '';
          };

          listenPort = mkOption {
            default = 51820;
            type = types.int;
            description = mdDoc "The port to listen on, if {option}`listen` is `true`.";
          };

          priority = mkOption {
            default = "20";
            type = types.str;
            description = mdDoc "The order priority used when creating systemd netdev and network files.";
          };

          openFirewall = mkOption {
            default = false;
            type = types.bool;
            description = mdDoc "Whether to open the firewall for the specified `listenPort`, if {option}`listen` is `true`.";
          };

          externalPeers = mkOption {
            type = types.attrsOf (types.listOf types.str);
            default = {};
            example = {my-android-phone = ["10.0.0.97/32"];};
            description = mdDoc ''
              Allows defining extra set of external peers that should be added to the configuration.
              For each external peers you can define one or multiple allowed ips.
            '';
          };
        };
      });
    };
  };

  config = mkIf (cfg.networks != {}) (let
    networkCfgs = mapAttrsToList configForNetwork cfg.networks;
    collectAttrs = x: foldl' mergeAttrs {} (map (y: y.${x}) networkCfgs);
  in {
    assertions =
      concatMap (netCfg: let
        inherit (netCfg) wgName;
        externalPeers = concatMap (n: attrNames nodes.${n}.config.extra.wireguard.networks.${wgName}.externalPeers) netCfg.nodesWithThisNetwork;
        duplicatePeers = duplicates externalPeers;
        usedAddresses =
          concatMap (n: nodes.${n}.config.extra.wireguard.networks.${wgName}.address) netCfg.nodesWithThisNetwork
          ++ flatten (concatMap (n: attrValues nodes.${n}.config.extra.wireguard.networks.${wgName}.externalPeers) netCfg.nodesWithThisNetwork);
        duplicateAddrs = duplicates (map (x: head (splitString "/" x)) usedAddresses);
      in [
        {
          assertion = any (n: nodes.${n}.config.extra.wireguard.networks.${wgName}.listen) netCfg.nodesWithThisNetwork;
          message = "Wireguard network '${wgName}': At least one node must be listening.";
        }
        {
          assertion = duplicatePeers == [];
          message = "Wireguard network '${wgName}': Multiple definitions for external peer(s):${concatMapStrings (x: " '${x}'") duplicatePeers}";
        }
        {
          assertion = duplicateAddrs == [];
          message = "Wireguard network '${wgName}': Addresses used multiple times: ${concatStringsSep ", " duplicateAddrs}";
        }
      ])
      networkCfgs;

    networking.firewall.allowedUDPPorts = mkIf (cfg.listen && cfg.openFirewall) [cfg.listenPort];
    rekey.secrets = collectAttrs "secrets";
    systemd.network = {
      netdevs = collectAttrs "netdevs";
      networks = collectAttrs "networks";
    };
  });
}
