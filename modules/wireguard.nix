{
  config,
  lib,
  extraLib,
  pkgs,
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
    mkForce
    mkIf
    mkOption
    optionalAttrs
    optionals
    stringLength
    types
    ;

  inherit
    (extraLib)
    concatAttrs
    duplicates
    mergeToplevelConfigs
    ;

  inherit
    (extraLib.types)
    lazyOf
    lazyValue
    ;

  inherit (config.lib) net;
  cfg = config.extra.wireguard;

  configForNetwork = wgName: wgCfg: let
    inherit
      (extraLib.wireguard wgName)
      externalPeerName
      externalPeerNamesRaw
      networkCidrs
      participatingClientNodes
      participatingNodes
      participatingServerNodes
      peerPresharedKeyPath
      peerPresharedKeySecret
      peerPrivateKeyPath
      peerPrivateKeySecret
      peerPublicKeyPath
      toNetworkAddr
      usedAddresses
      wgCfgOf
      ;

    isServer = wgCfg.server.host != null;
    isClient = wgCfg.client.via != null;
    filterSelf = filter (x: x != nodeName);

    # All nodes that use our node as the via into the wireguard network
    ourClientNodes =
      optionals isServer
      (filter (n: (wgCfgOf n).client.via == nodeName) participatingClientNodes);

    # The list of peers for which we have to know the psk.
    neededPeers =
      if isServer
      then
        # Other servers in the same network
        filterSelf participatingServerNodes
        # Our external peers
        ++ map externalPeerName (attrNames wgCfg.server.externalPeers)
        # Our clients
        ++ ourClientNodes
      else [wgCfg.client.via];

    # Figure out if there are duplicate peers or addresses so we can
    # make an assertion later.
    duplicatePeers = duplicates externalPeerNamesRaw;
    duplicateAddrs = duplicates usedAddresses;

    # Adds context information to the assertions for this network
    assertionPrefix = "Wireguard network '${wgName}' on '${nodeName}'";

    # Calculates the allowed ips for another server from our perspective.
    # Usually we just want to allow other peers to route traffic
    # for our "children" through us, additional to traffic to us of course.
    # If a server exposes additional network access (global, lan, ...),
    # these can be added aswell.
    # TODO (do that)
    serverAllowedIPs = serverNode: let
      snCfg = wgCfgOf serverNode;
    in
      map (net.cidr.make 128) (
        # The server accepts traffic to it's own address
        snCfg.addresses
        # plus traffic for any of its external peers
        ++ attrValues snCfg.server.externalPeers
        # plus traffic for any client that is connected via that server
        ++ concatMap (n: (wgCfgOf n).addresses) (filter (n: (wgCfgOf n).client.via == serverNode) participatingClientNodes)
      );
  in {
    assertions = [
      {
        assertion = any (n: (wgCfgOf n).server.host != null) participatingNodes;
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
      {
        assertion = stringLength wgCfg.linkName < 16;
        message = "${assertionPrefix}: The specified linkName '${wgCfg.linkName}' is too long (must be max 15 characters).";
      }
      # TODO at least 3 network participants and (externalPeers != {} or someone has via set to us) -> ip forwarding
    ];

    networking.firewall.allowedUDPPorts =
      mkIf
      (isServer && wgCfg.server.openFirewall)
      [wgCfg.server.port];

    # Open the port in the given nftables rule if specified
    # TODO mkForce nftables
    networking.nftables.firewall.rules = mkForce (
      optionalAttrs (isServer && wgCfg.server.openFirewallRules != [])
      (genAttrs wgCfg.server.openFirewallRules (_: {allowedUDPPorts = [wgCfg.server.port];}))
    );

    age.secrets =
      concatAttrs (map
        (other: {
          ${peerPresharedKeySecret nodeName other} = {
            rekeyFile = peerPresharedKeyPath nodeName other;
            owner = "systemd-network";
            # TODO gen func
          };
        })
        neededPeers)
      // {
        ${peerPrivateKeySecret nodeName} = {
          rekeyFile = peerPrivateKeyPath nodeName;
          owner = "systemd-network";
          # TODO gen func
        };
      };

    systemd.network.netdevs."${wgCfg.unitConfName}" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = wgCfg.linkName;
        Description = "Wireguard network ${wgName}";
      };
      wireguardConfig =
        {
          PrivateKeyFile = config.age.secrets.${peerPrivateKeySecret nodeName}.path;
        }
        // optionalAttrs isServer {
          ListenPort = wgCfg.server.port;
        };
      wireguardPeers =
        if isServer
        then
          # Always include all other server nodes.
          map (serverNode: let
            snCfg = wgCfgOf serverNode;
          in {
            wireguardPeerConfig = {
              PublicKey = builtins.readFile (peerPublicKeyPath serverNode);
              PresharedKeyFile = config.age.secrets.${peerPresharedKeySecret nodeName serverNode}.path;
              AllowedIPs = serverAllowedIPs serverNode;
              Endpoint = "${snCfg.server.host}:${toString snCfg.server.port}";
            };
          })
          (filterSelf participatingServerNodes)
          # All our external peers
          ++ mapAttrsToList (extPeer: ips: let
            peerName = externalPeerName extPeer;
          in {
            wireguardPeerConfig = {
              PublicKey = builtins.readFile (peerPublicKeyPath peerName);
              PresharedKeyFile = config.age.secrets.${peerPresharedKeySecret nodeName peerName}.path;
              AllowedIPs = map (net.cidr.make 128) ips;
              # Connections to external peers should always be kept alive
              PersistentKeepalive = 25;
            };
          })
          wgCfg.server.externalPeers
          # All client nodes that have their via set to us.
          ++ map (clientNode: let
            clientCfg = wgCfgOf clientNode;
          in {
            wireguardPeerConfig = {
              PublicKey = builtins.readFile (peerPublicKeyPath clientNode);
              PresharedKeyFile = config.age.secrets.${peerPresharedKeySecret nodeName clientNode}.path;
              AllowedIPs = map (net.cidr.make 128) clientCfg.addresses;
            };
          })
          ourClientNodes
        else
          # We are a client node, so only include our via server.
          [
            {
              wireguardPeerConfig = let
                snCfg = wgCfgOf wgCfg.client.via;
              in
                {
                  PublicKey = builtins.readFile (peerPublicKeyPath wgCfg.client.via);
                  PresharedKeyFile = config.age.secrets.${peerPresharedKeySecret nodeName wgCfg.client.via}.path;
                  Endpoint = "${snCfg.server.host}:${toString snCfg.server.port}";
                  # Access to the whole network is routed through our entry node.
                  # TODO this should add any routedAddresses on ANY server in the network, right?
                  # if A entries via B and only C can route 0.0.0.0/0, does that work?
                  AllowedIPs = networkCidrs;
                }
                // optionalAttrs wgCfg.client.keepalive {
                  PersistentKeepalive = 25;
                };
            }
          ];
    };

    systemd.network.networks."${wgCfg.unitConfName}" = {
      matchConfig.Name = wgCfg.linkName;
      address = map toNetworkAddr wgCfg.addresses;
    };
  };
in {
  options.extra.wireguard = mkOption {
    default = {};
    description = "Configures wireguard networks via systemd-networkd.";
    type = types.lazyAttrsOf (types.submodule ({
      config,
      name,
      options,
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

          openFirewallRules = mkOption {
            default = [];
            type = types.listOf types.str;
            description = mdDoc "The {option}`port` will be opened for all of the given rules in the nftable-firewall.";
          };

          externalPeers = mkOption {
            type = types.attrsOf (types.listOf (net.types.ip-in config.addresses));
            default = {};
            example = {my-android-phone = ["10.0.0.97"];};
            description = mdDoc ''
              Allows defining an extra set of peers that should be added to this wireguard network,
              but will not be managed by this flake. (e.g. phones)

              These external peers will only know this node as a peer, which will forward
              their traffic to other members of the network if required. This requires
              this node to act as a server.
            '';
          };

          reservedAddresses = mkOption {
            type = types.listOf net.types.cidr;
            default = [];
            example = ["10.0.0.1/24" "fd00:cafe::/64"];
            description = mdDoc ''
              Allows defining extra cidr network ranges that shall be reserved for this network.
              Reservation means that those address spaces will be guaranteed to be included in
              the spanned network, but no rules will be enforced as to who in the network may use them.

              By default, this module will try to allocate the smallest address space that includes
              all network peers. If you know that there might be additional external peers added later,
              it may be beneficial to reserve a bigger address space from the start to avoid having
              to update existing external peers when the generated address space expands.
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
        };

        priority = mkOption {
          default = 40;
          type = types.int;
          description = mdDoc "The order priority used when creating systemd netdev and network files.";
        };

        linkName = mkOption {
          default = name;
          type = types.str;
          description = mdDoc "The name for the created network interface.";
        };

        unitConfName = mkOption {
          default = "${toString config.priority}-${config.linkName}";
          readOnly = true;
          type = types.str;
          description = mdDoc ''
            The name used for unit configuration files. This is a read-only option.
            Access this if you want to add additional settings to the generated systemd units.
          '';
        };

        ipv4 = mkOption {
          type = lazyOf net.types.ipv4;
          default = lazyValue (extraLib.wireguard name).assignedIpv4Addresses.${nodeName};
          description = mdDoc ''
            The ipv4 address for this machine. If you do not set this explicitly,
            a semi-stable ipv4 address will be derived automatically based on the
            hostname of this machine. At least one participating server must reserve
            a big-enough space of addresses by setting `reservedAddresses`.
            See `net.cidr.assignIps` for more information on the algorithm.
          '';
        };

        ipv6 = mkOption {
          type = lazyOf net.types.ipv6;
          default = lazyValue (extraLib.wireguard name).assignedIpv6Addresses.${nodeName};
          description = mdDoc ''
            The ipv6 address for this machine. If you do not set this explicitly,
            a semi-stable ipv6 address will be derived automatically based on the
            hostname of this machine. At least one participating server must reserve
            a big-enough space of addresses by setting `reservedAddresses`.
            See `net.cidr.assignIps` for more information on the algorithm.
          '';
        };

        addresses = mkOption {
          type = types.listOf (lazyOf net.types.ip);
          default = [
            (head options.ipv4.definitions)
            (head options.ipv6.definitions)
          ];
          description = mdDoc ''
            The ip addresses (v4 and/or v6) to use for this machine.
            The actual network cidr will automatically be derived from all network participants.
            By default this will just include {option}`ipv4` and {option}`ipv6` as configured.
          '';
        };

        # TODO this is not yet implemented.
        # - is 0.0.0.0/0 also for valid for routing global ipv6?
        # - is 0.0.0.0/0 routing private spaces such as 192.168.1 ? that'd be baaad
        # - force nodes to opt-in or allow nodes to opt-out? sometimes a node want's
        #   to use the network without routing additional stuff.
        # - allow specifying the route metric.
        routedAddresses = mkOption {
          type = types.listOf net.types.cidr;
          default = [];
          example = ["0.0.0.0/0"];
          description = mdDoc ''
            Additional networks that are accessible through this machine. This will allow
            other participants of the network to access these networks through the tunnel.

            Make sure to configure a NAT on the created interface (or that the proper routes
            are generated) to allow inter-network communication.
          '';
        };
      };
    }));
  };

  config = mkIf (cfg != {}) (mergeToplevelConfigs
    ["assertions" "age" "networking" "systemd"]
    (mapAttrsToList configForNetwork cfg));
}
