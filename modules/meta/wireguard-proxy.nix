{
  config,
  lib,
  nodes,
  ...
}: let
  inherit
    (lib)
    attrNames
    flip
    mdDoc
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.meta.wireguard-proxy;
in {
  options.meta.wireguard-proxy = mkOption {
    default = {};
    description = mdDoc ''
      Each entry here will setup a wireguard network that connects via the
      given node and adds appropriate firewall zones. There will a zone for
      the interface and one for the proxy server specifically. A corresponding
      rule `''${name}-to-local` will be created to easily expose services to the proxy.
    '';
    type = types.attrsOf (types.submodule ({name, ...}: {
      options = {
        nicName = mkOption {
          type = types.str;
          default = "proxy-${name}";
          description = mdDoc "The name for the created wireguard network and its interface";
        };
        allowedTCPPorts = mkOption {
          type = types.listOf types.int;
          default = [];
          description = mdDoc "Convenience option to allow incoming TCP connections from the proxy server (just the server, not the entire network).";
        };
        allowedUDPPorts = mkOption {
          type = types.listOf types.int;
          default = [];
          description = mdDoc "Convenience option to allow incoming UDP connections from the proxy server (just the server, not the entire network).";
        };
      };
    }));
  };

  config = mkIf (cfg != {}) {
    meta.wireguard = mkMerge (flip map (attrNames cfg) (proxy: {
      ${cfg.${proxy}.nicName}.client.via = proxy;
    }));

    networking.nftables.firewall = mkMerge (flip map (attrNames cfg) (proxy: {
      zones = {
        # Parent zone for the whole interface
        ${cfg.${proxy}.nicName}.interfaces = [cfg.${proxy}.nicName];
        # Subzone to specifically target the proxy host
        ${proxy} = {
          parent = cfg.${proxy}.nicName;
          ipv4Addresses = [nodes.${proxy}.config.meta.wireguard.${cfg.${proxy}.nicName}.ipv4];
          ipv6Addresses = [nodes.${proxy}.config.meta.wireguard.${cfg.${proxy}.nicName}.ipv6];
        };
      };

      rules."${proxy}-to-local" = {
        from = [proxy];
        to = ["local"];

        inherit
          (cfg.${proxy})
          allowedTCPPorts
          allowedUDPPorts
          ;
      };
    }));
  };
}
