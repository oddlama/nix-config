{
  networking = {
    hostId = "49ce3b71";
  };

  systemd.network.networks = {
    "10-lan0" = {
      DHCP = "yes";
      matchConfig.MACAddress = "00:00:00:00:00:00";
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    "10-lan1" = {
      DHCP = "yes";
      matchConfig.MACAddress = "00:00:00:00:00:00";
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 20;
      dhcpV6Config.RouteMetric = 20;
    };
  };
}
