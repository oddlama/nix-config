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
    concatMap
    concatMapStrings
    concatStringsSep
    filterAttrs
    head
    mapAttrsToList
    mdDoc
    mergeAttrs
    mkIf
    mkOption
    mkEnableOption
    optionalAttrs
    splitString
    types
    ;

  inherit
    (extraLib)
    concatAttrs
    duplicates
    ;

  cfg = config.extra.wireguard;

  configForNetwork = wgName: wg: let
    inherit
      (extraLib.wireguard wgName)
      allPeers
      peerPresharedKeyPath
      peerPresharedKeySecret
      peerPrivateKeyPath
      peerPrivateKeySecret
      peerPublicKeyPath
      ;

    otherPeers = filterAttrs (n: _: n != nodeName) (allPeers nodes);
  in {
    secrets =
      concatAttrs (map (other: {
        ${peerPresharedKeySecret nodeName other}.file = peerPresharedKeyPath nodeName other;
      }) (attrNames otherPeers))
      // {
        ${peerPrivateKeySecret nodeName}.file = peerPrivateKeyPath nodeName;
      };

    netdevs."${wg.priority}-${wgName}" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = "${wgName}";
        Description = "Wireguard network ${wgName}";
      };
      wireguardConfig =
        {
          PrivateKeyFile = config.rekey.secrets.${peerPrivateKeySecret nodeName}.path;
        }
        // optionalAttrs wg.server.enable {
          ListenPort = wg.server.port;
        };
      wireguardPeers =
        mapAttrsToList (peerName: peerAllowedIPs: {
          wireguardPeerConfig =
            {
              PublicKey = builtins.readFile (peerPublicKeyPath peerName);
              PresharedKeyFile = config.rekey.secrets.${peerPresharedKeySecret nodeName peerName}.path;
              AllowedIPs = peerAllowedIPs;
            }
            // optionalAttrs wg.server.enable {
              PersistentKeepalive = 25;
            };
        })
        otherPeers;
    };

    networks."${wg.priority}-${wgName}" = {
      matchConfig.Name = wgName;
      networkConfig.Address = wg.address;
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

          port = mkOption {
            default = 51820;
            type = types.port;
            description = mdDoc "The port to listen on, if {option}`listen` is `true`.";
          };

          openFirewall = mkOption {
            default = false;
            type = types.bool;
            description = mdDoc "Whether to open the firewall for the specified `listenPort`, if {option}`listen` is `true`.";
          };
        };

        priority = mkOption {
          default = "20";
          type = types.str;
          description = mdDoc "The order priority used when creating systemd netdev and network files.";
        };

        address = mkOption {
          type = types.listOf types.str;
          description = mdDoc ''
            The addresses to configure for this interface. Will automatically be added
            as this peer's allowed addresses to all other peers.
          '';
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

      duplicatePeers = duplicates (externalPeerNamesRaw nodes);
      duplicateAddrs = duplicates (map (x: head (splitString "/" x)) (usedAddresses nodes));
    in [
      {
        assertion = any (n: nodes.${n}.config.extra.wireguard.${wgName}.server.enable) (associatedNodes nodes);
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
    ]) (attrNames cfg);

    networking.firewall.allowedUDPPorts = mkIf (cfg.server.enable && cfg.server.openFirewall) [cfg.server.port];
    rekey.secrets = collectAllNetworkAttrs "secrets";
    systemd.network = {
      netdevs = collectAllNetworkAttrs "netdevs";
      networks = collectAllNetworkAttrs "networks";
    };
  });
}
