{
  config,
  globals,
  ...
}:
{
  networking.hostId = config.repo.secrets.local.networking.hostId;

  # FIXME: aaaaaaaaa
  # globals.monitoring.ping.sausebiene = {
  #   hostv4 = lib.net.cidr.ip globals.net.home-lan.vlans.services.hosts.sausebiene.cidrv4;
  #   hostv6 = lib.net.cidr.ip globals.net.home-lan.vlans.services.hosts.sausebiene.cidrv6;
  #   network = "home-lan.vlans.services";
  # };

  boot.initrd.availableKernelModules = [ "8021q" ];
  boot.initrd.systemd.network = {
    enable = true;
    networks = {
      inherit (config.systemd.network.networks) "10-lan";
    };
  };

  systemd.network.networks = {
    "10-lan" = {
      address = [ "192.168.1.17/24" ];
      gateway = [ globals.net.home-lan.vlans.services.hosts.ward.ipv4 ];
      matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
      networkConfig = {
        IPv6PrivacyExtensions = "yes";
        MulticastDNS = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  networking.nftables.firewall = {
    zones.untrusted.interfaces = [ "lan" ];
  };

  # Allow accessing influx
  wireguard.proxy-sentinel.client.via = "sentinel";
}
