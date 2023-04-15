{
  lib,
  nodeSecrets,
  ...
}: {
  networking.hostId = "49ce3b71";

  systemd.network.networks = {
    "10-lan1" = {
      DHCP = "yes";
      matchConfig.MACAddress = nodeSecrets.networking.interfaces.lan1.mac;
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    "10-lan2" = {
      DHCP = "yes";
      matchConfig.MACAddress = nodeSecrets.networking.interfaces.lan2.mac;
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 20;
      dhcpV6Config.RouteMetric = 20;
    };
  };

  #extra.wireguard.vms = {
  #  server = {
  #    enable = true;
  #    host = "192.168.1.231";
  #    port = 51822;
  #    openFirewall = true;
  #  };
  #  addresses = ["10.0.0.1/24"];
  #};
}
