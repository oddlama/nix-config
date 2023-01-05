{
  networking = {
    hostId = "49ce3b71";
    hostName = "ward";
    wireless.iwd.enable = true;
  };

  systemd.network.networks = {
    enp1s0 = {
      DHCP = "yes";
      matchConfig.MACAddress = "00:00:00:00:00:00";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    enp2s0 = {
      DHCP = "yes";
      matchConfig.MACAddress = "00:00:00:00:00:00";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
  };
}
