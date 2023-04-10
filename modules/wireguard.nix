{
  config,
  lib,
  pkgs,
  nodes,
  nodeName,
  ...
}: let
  inherit
    (lib)
    attrNames
    concatMapAttrs
    filter
    foldl'
    genAttrs
    mapAttrsToList
    mapAttrs'
    mdDoc
    mkIf
    mkOption
    nameValuePair
    recursiveUpdate
    types
    ;

  cfg = config.extra.wireguard;

  peerPublicKey = wgName: peerName: builtins.readFile (../secrets/wireguard + "/${wgName}/${peerName}.pub");
  peerPrivateKeyFile = wgName: peerName: ../secrets/wireguard + "/${wgName}/${peerName}.priv.age";
  peerPrivateKeySecret = wgName: peerName: "wireguard-${wgName}-${peerName}.priv";

  peerPresharedKeyFile = wgName: peerA: peerB: let
    sortedPeers =
      if peerA < peerB
      then {
        peer1 = peerA;
        peer2 = peerB;
      }
      else {
        peer1 = peerB;
        peer2 = peerA;
      };
    inherit (sortedPeers) peer1 peer2;
  in
    ../secrets/wireguard + "/${wgName}/${peer1}-${peer2}.psk.age";

  peerPresharedKeySecret = wgName: peerA: peerB: let
    sortedPeers =
      if peerA < peerB
      then {
        peer1 = peerA;
        peer2 = peerB;
      }
      else {
        peer1 = peerB;
        peer2 = peerA;
      };
    inherit (sortedPeers) peer1 peer2;
  in "wireguard-${wgName}-${peer1}-${peer2}.psk";

  peerDefinition = wgName: peerName: peerAllowedIPs: {
    wireguardPeerConfig = {
      PublicKey = peerPublicKey wgName peerName;
      PresharedKeyFile = config.rekey.secrets.${peerPresharedKeySecret wgName nodeName peerName}.path;
      AllowedIPs = peerAllowedIPs;

      # TODO only if we are the ones listening
      PersistentKeepalive = 25;
    };
  };

  configForNetwork = wgName: wg: let
    # All peers that are other nodes
    nodePeerNames = filter (n: n != nodeName && builtins.hasAttr wgName nodes.${n}.config.extra.wireguard.networks) (attrNames nodes);
    nodePeers = genAttrs nodePeerNames (n: nodes.${n}.config.extra.wireguard.networks.${wgName}.address);
    # All peers that are defined as externalPeers on any node. Also prepends "external-" to their name.
    externalPeers = foldl' recursiveUpdate {} (map (n: mapAttrs' (extPeerName: nameValuePair "external-${extPeerName}") nodes.${n}.config.extra.wireguard.networks.${wgName}.externalPeers) (attrNames nodes));

    peers = nodePeers // externalPeers;
  in {
    rekey.secrets =
      foldl' recursiveUpdate {
        ${peerPrivateKeySecret wgName nodeName}.file = peerPrivateKeyFile wgName nodeName;
      } (map (peerName: {
        ${peerPresharedKeySecret wgName nodeName peerName}.file = peerPresharedKeyFile wgName nodeName peerName;
      }) (attrNames peers));

    systemd.network = {
      netdevs."${wg.priority}-${wgName}" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "${wgName}";
          Description = "Wireguard network ${wgName}";
        };
        wireguardConfig = {
          PrivateKeyFile = config.rekey.secrets.${peerPrivateKeySecret wgName nodeName}.path;
          ListenPort = wg.listenPort;
        };
        wireguardPeers = mapAttrsToList (peerDefinition wgName) peers;
      };

      networks."${wg.priority}-${wgName}" = {
        matchConfig.Name = wgName;
        networkConfig.Address = wg.address;
      };
    };
  };
in {
  options = {
    networks = mkOption {
      default = {};
      description = "";
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

  config = mkIf (cfg.networks != {}) ({
      # TODO assert that at least one peer has listen true
      # TODO assert that no external peers are specified twice in different node configs
      #assertions = [];

      networking.firewall.allowedUDPPorts = mkIf (cfg.listen && cfg.openFirewall) [cfg.listenPort];
    }
    // foldl' recursiveUpdate {} (map configForNetwork cfg.networks));
}
