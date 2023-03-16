{nodeSecrets, ...}: {
  networking.hostId = "f7e6acdc";

  systemd.network.networks = {
    "10-lan1" = {
      DHCP = "yes";
      matchConfig.MACAddress = nodeSecrets.networking.interfaces.lan1.mac;
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    "10-wlan1" = {
      DHCP = "no";
      matchConfig.MACAddress = nodeSecrets.networking.interfaces.wlan1.mac;
      networkConfig = {
        Address = "10.90.0.1/24";
        Gateway = "10.90.0.1";
      };
    };
  };
}
