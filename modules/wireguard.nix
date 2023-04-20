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
    filterAttrs
    head
    mapAttrsToList
    mdDoc
    mergeAttrs
    mkIf
    mkOption
    mkEnableOption
    net
    optionalAttrs
    optionals
    splitString
    types
    ;

  inherit
    (extraLib)
    concatAttrs
    duplicates
    ;

  cfg = config.extra.wireguard;

  configForNetwork = wgName: wgCfg: let
    inherit
      (extraLib.wireguard wgName)
      associatedServerNodes
      associatedClientNodes
      externalPeerName
      peerPresharedKeyPath
      peerPresharedKeySecret
      peerPrivateKeyPath
      peerPrivateKeySecret
      peerPublicKeyPath
      ;

    filterSelf = filter (x: x != nodeName);
    wgCfgOf = node: nodes.${node}.config.extra.wireguard.${wgName};

    ourClientNodes =
      optionals wgCfg.server.enable
      (filter (n: (wgCfgOf n).via == nodeName) associatedClientNodes);

    # The list of peers that we have to know the psk to.
    neededPeers =
      if wgCfg.server.enable
      then
        filterSelf associatedServerNodes
        ++ map externalPeerName (attrNames wgCfg.server.externalPeers)
        ++ ourClientNodes
      else [wgCfg.via];
  in {
    secrets =
      concatAttrs (map (other: {
          ${peerPresharedKeySecret nodeName other}.file = peerPresharedKeyPath nodeName other;
        })
        neededPeers)
      // {
        ${peerPrivateKeySecret nodeName}.file = peerPrivateKeyPath nodeName;
      };

    netdevs."${wgCfg.priority}-${wgName}" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = "${wgName}";
        Description = "Wireguard network ${wgName}";
      };
      wireguardConfig =
        {
          PrivateKeyFile = config.rekey.secrets.${peerPrivateKeySecret nodeName}.path;
        }
        // optionalAttrs wgCfg.server.enable {
          ListenPort = wgCfg.server.port;
        };
      wireguardPeers =
        if wgCfg.server.enable
        then
          # Always include all other server nodes.
          map (serverNode: let
            snCfg = wgCfgOf serverNode;
          in {
            wireguardPeerConfig = {
              PublicKey = builtins.readFile (peerPublicKeyPath serverNode);
              PresharedKeyFile = config.rekey.secrets.${peerPresharedKeySecret nodeName serverNode}.path;
              # The allowed ips of a server node are it's own addreses,
              # plus each external peer's addresses,
              # plus each client's addresses that is connected via that node.
              AllowedIPs = snCfg.addresses;
              # TODO this needed? or even wanted at all?
              # ++ attrValues snCfg.server.externalPeers;
              # ++ map (n: (wgCfgOf n).addresses) snCfg.ourClientNodes;
              Endpoint = "${snCfg.server.host}:${toString snCfg.server.port}";
            };
          }) (filterSelf associatedServerNodes)
          # All our external peers
          ++ mapAttrsToList (extPeer: allowedIPs: let
            peerName = externalPeerName extPeer;
          in {
            wireguardPeerConfig = {
              PublicKey = builtins.readFile (peerPublicKeyPath peerName);
              PresharedKeyFile = config.rekey.secrets.${peerPresharedKeySecret nodeName peerName}.path;
              AllowedIPs = allowedIPs;
              PersistentKeepalive = 25;
            };
          })
          wgCfg.server.externalPeers
          # All client nodes that have their via set to us.
          ++ mapAttrsToList (clientNode: {
            wireguardPeerConfig = {
              PublicKey = builtins.readFile (peerPublicKeyPath clientNode);
              PresharedKeyFile = config.rekey.secrets.${peerPresharedKeySecret nodeName clientNode}.path;
              AllowedIPs = (wgCfgOf clientNode).addresses;
              PersistentKeepalive = 25;
            };
          })
          ourClientNodes
        else
          # We are a client node, so only include our via server.
          [
            {
              wireguardPeerConfig = {
                PublicKey = builtins.readFile (peerPublicKeyPath wgCfg.via);
                PresharedKeyFile = config.rekey.secrets.${peerPresharedKeySecret nodeName wgCfg.via}.path;
                AllowedIPs = (wgCfgOf wgCfg.via).addresses;
              };
            }
          ];
    };

    networks."${wgCfg.priority}-${wgName}" = {
      matchConfig.Name = wgName;
      networkConfig.Address = wgCfg.addresses;
    };
  };
in {
  options.extra.wireguard = mkOption {
    default = {};
    description = "Configures wireguard networks via systemd-networkd.";
    type = types.attrsOf (types.submodule {
      options = {
        server = {
          enable = mkEnableOption (mdDoc "wireguard server");

          host = mkOption {
            type = types.str;
            description = mdDoc "The hostname or ip address which other peers can use to reach this host.";
          };

          port = mkOption {
            default = 51820;
            type = types.port;
            description = mdDoc "The port to listen on.";
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
              Allows defining an extra set of peers that should be added to this wireguard network,
              but will not be managed by this flake. (e.g. phones)

              These external peers will only know this node as a peer, which will forward
              their traffic to other members of the network if required. This requires
              this node to act as a server.
            '';
          };
        };

        priority = mkOption {
          default = "20";
          type = types.str;
          description = mdDoc "The order priority used when creating systemd netdev and network files.";
        };

        via = mkOption {
          default = null;
          type = types.uniq (types.nullOr types.str);
          description = mdDoc ''
            The server node via which to connect to the network.
            This must defined if and only if this node is not a server.
          '';
        };

        addresses = mkOption {
          type = types.listOf types.str;
          description = mdDoc ''
            The addresses to configure for this interface. Will automatically be added
            as this peer's allowed addresses to all other peers.
          '';
        };
      };
    });
  };

  config = mkIf (cfg != {}) (let
    networkCfgs = mapAttrsToList configForNetwork cfg;
    collectAllNetworkAttrs = x: concatAttrs (map (y: y.${x}) networkCfgs);
  in {
    assertions = concatMap (wgName: let
      inherit
        (extraLib.wireguard wgName)
        externalPeerNamesRaw
        usedAddresses
        associatedNodes
        ;

      wgCfg = cfg.${wgName};
      wgCfgOf = node: nodes.${node}.config.extra.wireguard.${wgName};
      duplicatePeers = duplicates externalPeerNamesRaw;
      duplicateAddrs = duplicates (map (x: head (splitString "/" x)) usedAddresses);
    in [
      {
        assertion = any (n: nodes.${n}.config.extra.wireguard.${wgName}.server.enable) associatedNodes;
        message = "Wireguard network '${wgName}': At least one node must be a server.";
      }
      {
        assertion = duplicatePeers == [];
        message = "Wireguard network '${wgName}': Multiple definitions for external peer(s):${concatMapStrings (x: " '${x}'") duplicatePeers}";
      }
      {
        assertion = duplicateAddrs == [];
        message = "Wireguard network '${wgName}': Addresses used multiple times: ${concatStringsSep ", " duplicateAddrs}";
      }
      {
        assertion = wgCfg.server.externalPeers != {} -> wgCfg.server.enable;
        message = "Wireguard network '${wgName}': Defining external peers requires server.enable = true.";
      }
      {
        assertion = wgCfg.server.enable == (wgCfg.via == null);
        message = "Wireguard network '${wgName}': A via server must be defined exactly iff this isn't a server node.";
      }
      {
        assertion = wgCfg.via != null -> (wgCfgOf wgCfg.via).server.enable;
        message = "Wireguard network '${wgName}': The specified via node '${wgCfg.via}' must be a wireguard server.";
      }
      # TODO externalPeers != {} -> ip forwarding
      # TODO no overlapping allowed ip range? 0.0.0.0 would be ok to overlap though
    ]) (attrNames cfg);

    networking.firewall.allowedUDPPorts = mkIf (cfg.server.enable && cfg.server.openFirewall) [cfg.server.port];
    rekey.secrets = collectAllNetworkAttrs "secrets";
    systemd.network = {
      netdevs = collectAllNetworkAttrs "netdevs";
      networks = collectAllNetworkAttrs "networks";
    };
  });
}
