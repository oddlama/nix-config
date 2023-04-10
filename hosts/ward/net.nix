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

  imports = [../../modules/wireguard.nix];
  extra.wireguard.networks.vms = {
    address = ["10.0.0.1/24"];
    listen = true;
    listenPort = 51822;
    openFirewall = true;
    externalPeers = {
      test = ["10.0.0.91/32"];
    };
  };
}
