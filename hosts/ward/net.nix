{nodeSecrets, ...}: let
  wgName = "wg-vms";
  wgPort = 51820;
in {
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

  #systemd.network.netdevs."20-${wgName}" = {
  #  netdevConfig = {
  #    Kind = "wireguard";
  #    Name = "${wgName}";
  #    Description = "Wireguard network ${wgName}";
  #  };
  #  wireguardConfig = {
  #    PrivateKeyFile = wireguardPrivateKey wgName nodeMeta.name;
  #    ListenPort = wgPort;
  #  };
  #  wireguardPeers = [
  #  {
  #    wireguardPeerConfig = {
  #      PublicKey = wireguardPublicKey wgName nodeMeta.name;;
  #      PresharedKey = wireguardPresharedKey wgName nodeMeta.name;;
  #      AllowedIPs = [ "10.66.66.10/32" ];
  #      PersistentKeepalive = 25;
  #    };
  #  }
  #  {
  #    wireguardPeerConfig = {
  #      AllowedIPs = [ "10.66.66.100/32" ];
  #      PersistentKeepalive = 25;
  #    };
  #  }
  #  ];
  #};
  #networks."20-${wgName}" = {
  #  matchConfig.Name = wgName;
  #  networkConfig = {
  #    Address = "10.66.66.1/24";
  #    IPForward = "ipv4";
  #  };
  #};

  #extra.wireguard.servers.home = {
  #};
}
