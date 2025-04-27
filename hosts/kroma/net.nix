{ config, ... }:
{
  networking = {
    inherit (config.repo.secrets.local.networking) hostId;
  };

  boot.initrd.systemd.network = {
    enable = true;
    networks = {
      inherit (config.systemd.network.networks) "10-lan1";
    };
  };

  systemd.network.networks = {
    "10-lan1" = {
      DHCP = "yes";
      matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan1.mac;
      networkConfig.IPv6PrivacyExtensions = "yes";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    "10-wlan1" = {
      DHCP = "yes";
      matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wlan1.mac;
      networkConfig.IPv6PrivacyExtensions = "yes";
      dhcpV4Config.RouteMetric = 40;
      dhcpV6Config.RouteMetric = 40;
    };
  };

  networking.nftables.firewall = {
    zones.untrusted.interfaces = [
      "lan1"
      "wlan1"
    ];
  };
}
