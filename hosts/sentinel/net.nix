{config, ...}: {
  networking.hostId = config.repo.secrets.local.networking.hostId;
  networking.domain = config.repo.secrets.local.personalDomain;

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

  networking.nftables.firewall = {
    zones = {
      untrusted.interfaces = ["wan"];
      proxy-sentinel.interfaces = ["proxy-sentinel"];
    };
    # Allow accessing nginx through the proxy
    rules.proxy-sentinel-to-local = {
      from = ["proxy-sentinel"];
      to = ["local"];
      allowedTCPPorts = [80 443];
    };
  };

  meta.wireguard.proxy-sentinel.server = {
    host = config.networking.fqdn;
    port = 51443;
    reservedAddresses = ["10.43.0.0/24" "fd00:43::/120"];
    openFirewallRules = ["untrusted-to-local"];
  };
}
