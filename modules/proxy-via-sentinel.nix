{
  lib,
  nodes,
  ...
}: {
  extra.wireguard.proxy-sentinel.client.via = "sentinel";

  networking.nftables.firewall = {
    zones = lib.mkForce {
      proxy-sentinel.interfaces = ["proxy-sentinel"];
      sentinel = {
        parent = "proxy-sentinel";
        ipv4Addresses = [nodes.sentinel.config.extra.wireguard.proxy-sentinel.ipv4];
        ipv6Addresses = [nodes.sentinel.config.extra.wireguard.proxy-sentinel.ipv6];
      };
    };

    rules = lib.mkForce {
      sentinel-to-local = {
        from = ["sentinel"];
        to = ["local"];
      };
    };
  };
}
