{
  networking = {
    hostId = "4313abca";
    wireless.iwd.enable = true;
  };

  systemd.network.networks = {
    "10-lan0" = {
      DHCP = "yes";
      matchConfig.MACAddress = "00:00:00:00:00:00";
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    "10-wlan0" = {
      DHCP = "yes";
      matchConfig.MACAddress = "00:00:00:00:00:00";
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 40;
      dhcpV6Config.RouteMetric = 40;
    };
  };
}
