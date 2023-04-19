{nodeSecrets, ...}: {
  networking = {
    inherit (nodeSecrets.networking) hostId;
    wireless.iwd.enable = true;
  };

  systemd.network.networks = {
    "10-lan1" = {
      DHCP = "yes";
      matchConfig.MACAddress = nodeSecrets.networking.interfaces.lan1.mac;
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    "10-wlan1" = {
      DHCP = "yes";
      matchConfig.MACAddress = nodeSecrets.networking.interfaces.wlan1.mac;
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 40;
      dhcpV6Config.RouteMetric = 40;
    };
  };
}
