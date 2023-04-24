{
  lib,
  config,
  nodeSecrets,
  ...
}: let
  inherit (config.lib.net) cidr;

  net.iot.ipv4cidr = "10.90.0.1/24";
  net.iot.ipv6cidr = "fd90::1/64";
in {
  networking.hostId = nodeSecrets.networking.hostId;

  boot.initrd.systemd.network = {
    enable = true;
    networks = {inherit (config.systemd.network.networks) "10-lan1";};
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
      address = [net.iot.ipv4cidr net.iot.ipv6cidr];
      matchConfig.MACAddress = nodeSecrets.networking.interfaces.wlan1.mac;
    };
  };

  networking.nftables.firewall = {
    zones = lib.mkForce {
      lan.interfaces = ["lan1"];
    };

    rules = lib.mkForce {
      int-to-local = {
        from = ["lan"];
        to = ["local"];

        inherit
          (config.networking.firewall)
          allowedTCPPorts
          allowedUDPPorts
          ;
      };
    };
  };
}
