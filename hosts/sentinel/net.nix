{
  config,
  lib,
  utils,
  ...
}: {
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

  # TODO mkForce nftables
  networking.nftables.firewall = {
    zones = lib.mkForce {
      untrusted.interfaces = ["wan"];
    };
  };

  extra.wireguard.proxy-sentinel.server = {
    host = config.networking.fqdn;
    port = 51443;
    reservedAddresses = ["10.43.0.0/24" "fd00:43::/120"];
    openFirewallRules = ["untrusted-to-local"];
  };
}
