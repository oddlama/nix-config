{
  networking = {
    hostId = "4313abca";
    hostName = "nom";
    wireless.iwd.enable = true;
  };

  systemd.network.networks = {
    wired = {
      DHCP = "yes";
      matchConfig.MACAddress = "00:00:00:00:00:00";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    wireless = {
      DHCP = "yes";
      matchConfig.MACAddress = "00:00:00:00:00:00";
      dhcpV4Config.RouteMetric = 40;
      dhcpV6Config.RouteMetric = 40;
    };
  };
}
