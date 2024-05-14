{config, ...}: {
  networking.hostId = config.repo.secrets.local.networking.hostId;
  networking.domain = config.repo.secrets.global.domains.mail.primary;
  networking.hosts."127.0.0.1" = ["mx1.${config.repo.secrets.global.domains.mail.primary}"];

  boot.initrd.systemd.network = {
    enable = true;
    networks = {inherit (config.systemd.network.networks) "10-wan";};
  };

  systemd.network.networks = {
    "10-wan" = let
      icfg = config.repo.secrets.local.networking.interfaces.wan;
    in {
      address = [
        icfg.hostCidrv4
        icfg.hostCidrv6
      ];
      gateway = ["fe80::1"];
      routes = [
        {routeConfig = {Destination = "172.31.1.1";};}
        {
          routeConfig = {
            Gateway = "172.31.1.1";
            GatewayOnLink = true;
          };
        }
      ];
      matchConfig.MACAddress = icfg.mac;
      networkConfig.IPv6PrivacyExtensions = "yes";
      linkConfig.RequiredForOnline = "routable";
    };
  };

  networking.nftables.firewall.zones.untrusted.interfaces = ["wan"];

  # Allow accessing influx
  wireguard.proxy-sentinel.client.via = "sentinel";
}
