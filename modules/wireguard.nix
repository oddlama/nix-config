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
    genAttrs
    head
    mapAttrsToList
    mdDoc
    mergeAttrs
    mkIf
    mkOption
    optionalAttrs
    optionals
    splitString
    types
    ;

  inherit
    (extraLib)
    concatAttrs
    duplicates
    mergeToplevelConfigs
    ;

  inherit (config.lib) net;
  cfg = config.extra.wireguard;

  configForNetwork = wgName: wgCfg: let
    inherit
      (extraLib.wireguard wgName)
      associatedNodes
      associatedServerNodes
      associatedClientNodes
      externalPeerName
      externalPeerNamesRaw
      peerPresharedKeyPath
      peerPresharedKeySecret
      peerPrivateKeyPath
      peerPrivateKeySecret
      peerPublicKeyPath
      usedAddresses
      ;

    isServer = wgCfg.server.host != null;
    isClient = wgCfg.client.via != null;

    filterSelf = filter (x: x != nodeName);
    wgCfgOf = node: nodes.${node}.config.extra.wireguard.${wgName};

    # All nodes that use our node as the via into the wireguard network
    ourClientNodes =
      optionals isServer
      (filter (n: (wgCfgOf n).client.via == nodeName) associatedClientNodes);

    # The list of peers for which we have to know the psk.
    neededPeers =
      if isServer
      then
        # Other servers in the same network
        filterSelf associatedServerNodes
        # Our external peers
        ++ map externalPeerName (attrNames wgCfg.server.externalPeers)
        # Our clients
        ++ ourClientNodes
      else [wgCfg.client.via];

    # Figure out if there are duplicate peers or addresses so we can
    # make an assertion later.
    duplicatePeers = duplicates externalPeerNamesRaw;
    duplicateAddrs = duplicates (map (x: head (splitString "/" x)) usedAddresses);

    # Adds context information to the assertions for this network
    assertionPrefix = "Wireguard network '${wgName}' on '${nodeName}'";
  in {
    assertions = [
      {
        assertion = any (n: (wgCfgOf n).server.host != null) associatedNodes;
        message = "${assertionPrefix}: At least one node in a network must be a server.";
      }
      {
        assertion = duplicatePeers == [];
        message = "${assertionPrefix}: Multiple definitions for external peer(s):${concatMapStrings (x: " '${x}'") duplicatePeers}";
      }
      {
        assertion = duplicateAddrs == [];
        message = "${assertionPrefix}: Addresses used multiple times: ${concatStringsSep ", " duplicateAddrs}";
      }
      {
        assertion = isServer != isClient;
        message = "${assertionPrefix}: A node must either be a server (define server.host) or a client (define client.via).";
      }
      {
        assertion = isClient -> ((wgCfgOf wgCfg.client.via).server.host != null);
        message = "${assertionPrefix}: The specified via node '${wgCfg.client.via}' must be a wireguard server.";
      }
      # TODO externalPeers != {} -> ip forwarding
      # TODO no overlapping cidrs in (external peers + peers using via = this).
      # TODO no overlapping cidrs between server nodes
    ];

    networking.firewall.allowedUDPPorts =
      mkIf
      (isServer && wgCfg.server.openFirewall)
      [wgCfg.server.port];

    networking.nftables.firewall.rules =
      mkIf
      (isServer && wgCfg.server.openFirewallInRules != [])
      (genAttrs wgCfg.server.openFirewallInRules (_: {allowedUDPPorts = [wgCfg.server.port];}));

    rekey.secrets =
      concatAttrs (map
        (other: {${peerPresharedKeySecret nodeName other}.file = peerPresharedKeyPath nodeName other;})
        neededPeers)
      // {${peerPrivateKeySecret nodeName}.file = peerPrivateKeyPath nodeName;};

    systemd.network.netdevs."${toString wgCfg.priority}-${wgName}" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = "${wgName}";
        Description = "Wireguard network ${wgName}";
      };
      wireguardConfig =
        {
          PrivateKeyFile = config.rekey.secrets.${peerPrivateKeySecret nodeName}.path;
        }
        // optionalAttrs isServer {
          ListenPort = wgCfg.server.port;
        };
      wireguardPeers =
        if isServer
        then
          # Always include all other server nodes.
          map (serverNode: {
            wireguardPeerConfig = let
              snCfg = wgCfgOf serverNode;
            in {
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
          })
          (filterSelf associatedServerNodes)
          # All our external peers
          ++ mapAttrsToList (extPeer: allowedIPs: let
            peerName = externalPeerName extPeer;
          in {
            wireguardPeerConfig = {
              PublicKey = builtins.readFile (peerPublicKeyPath peerName);
              PresharedKeyFile = config.rekey.secrets.${peerPresharedKeySecret nodeName peerName}.path;
              AllowedIPs = allowedIPs;
              # Connections to external peers should always be kept alive
              PersistentKeepalive = 25;
            };
          })
          wgCfg.server.externalPeers
          # All client nodes that have their via set to us.
          ++ mapAttrsToList (clientNode: let
            clientCfg = wgCfgOf clientNode;
          in {
            wireguardPeerConfig =
              {
                PublicKey = builtins.readFile (peerPublicKeyPath clientNode);
                PresharedKeyFile = config.rekey.secrets.${peerPresharedKeySecret nodeName clientNode}.path;
                AllowedIPs = clientCfg.addresses;
              }
              // optionalAttrs clientCfg.keepalive {
                PersistentKeepalive = 25;
              };
          })
          ourClientNodes
        else
          # We are a client node, so only include our via server.
          [
            {
              wireguardPeerConfig = {
                PublicKey = builtins.readFile (peerPublicKeyPath wgCfg.client.via);
                PresharedKeyFile = config.rekey.secrets.${peerPresharedKeySecret nodeName wgCfg.client.via}.path;
                # TODO this should be 0.0.0.0 if the client wants to route all traffic
                AllowedIPs = (wgCfgOf wgCfg.client.via).addresses;
              };
            }
          ];
    };

    systemd.network.networks."${toString wgCfg.priority}-${wgName}" = {
      matchConfig.Name = wgName;
      networkConfig.Address = wgCfg.addresses;
    };
  };
in {
  options.extra.wireguard = mkOption {
    default = {};
    description = "Configures wireguard networks via systemd-networkd.";
    type = types.lazyAttrsOf (types.submodule ({
      config,
      name,
      ...
    }: {
      options = {
        server = {
          host = mkOption {
            default = null;
            type = types.nullOr types.str;
            description = mdDoc "The hostname or ip address which other peers can use to reach this host. No server funnctionality will be activated if set to null.";
          };

          port = mkOption {
            default = 51820;
            type = types.port;
            description = mdDoc "The port to listen on.";
          };

          openFirewall = mkOption {
            default = false;
            type = types.bool;
            description = mdDoc "Whether to open the firewall for the specified {option}`port`.";
          };

          openFirewallInRules = mkOption {
            default = [];
            type = types.listOf types.str;
            description = mdDoc "The {option}`port` will be opened for all of the given rules in the nftable-firewall.";
          };

          externalPeers = mkOption {
            type = types.attrsOf (types.listOf (net.types.cidr-in config.addresses));
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

        client = {
          via = mkOption {
            default = null;
            type = types.nullOr types.str;
            description = mdDoc ''
              The server node via which to connect to the network.
              No client functionality will be activated if set to null.
            '';
          };

          keepalive = mkOption {
            default = true;
            type = types.bool;
            description = mdDoc "Whether to keep this connection alive using PersistentKeepalive. Set to false only for networks where client and server IPs are stable.";
          };

          # TODO one option for allowing it, but also one to allow defining two
          # profiles / interfaces that can be activated manually.
          #routeAllTraffic = mkOption {
          #  default = false;
          #  type = types.bool;
          #  description = mdDoc ''
          #    Whether to allow routing all traffic through the via server.
          #  '';
          #};
        };

        priority = mkOption {
          default = 40;
          type = types.int;
          description = mdDoc "The order priority used when creating systemd netdev and network files.";
        };

        addresses = mkOption {
          type = types.listOf (
            if config.client.via != null
            then net.types.cidr-in nodes.${config.client.via}.config.extra.wireguard.${name}.addresses
            else net.types.cidr
          );
          description = mdDoc ''
            The addresses to configure for this interface. Will automatically be added
            as this peer's allowed addresses on all other peers.
          '';
        };
      };
    }));
  };

  config = mkIf (cfg != {}) (mergeToplevelConfigs
    ["assertions" "rekey" "networking" "systemd"]
    (mapAttrsToList configForNetwork cfg));
}
