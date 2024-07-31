{
  config,
  globals,
  lib,
  ...
}: let
  icfg = config.repo.secrets.local.networking.interfaces.wan;
in {
  networking.hostId = config.repo.secrets.local.networking.hostId;
  networking.domain = globals.domains.mail.primary;
  networking.hosts."127.0.0.1" = ["mail.${globals.domains.mail.primary}"];

  globals.monitoring.ping.envoy = {
    hostv4 = lib.net.cidr.ip icfg.hostCidrv4;
    hostv6 = lib.net.cidr.ip icfg.hostCidrv6;
    network = "internet";
  };

  boot.initrd.systemd.network = {
    enable = true;
    networks = {inherit (config.systemd.network.networks) "10-wan";};
  };

  systemd.network.networks = {
    "10-wan" = {
      address = [
        icfg.hostCidrv4
        icfg.hostCidrv6
      ];
      gateway = ["fe80::1"];
      routes = [
        {Destination = "172.31.1.1";}
        {
          Gateway = "172.31.1.1";
          GatewayOnLink = true;
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
