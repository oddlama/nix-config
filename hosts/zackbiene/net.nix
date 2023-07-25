{
  config,
  lib,
  ...
}: let
  iotCidrv4 = "10.90.0.0/24";
  iotCidrv6 = "fd00:90::/64";
in {
  networking.hostId = config.repo.secrets.local.networking.hostId;

  boot.initrd.systemd.network = {
    enable = true;
    networks = {inherit (config.systemd.network.networks) "10-lan1";};
  };

  systemd.network.networks = {
    "10-lan1" = {
      DHCP = "yes";
      dhcpV4Config.UseDNS = false;
      dhcpV6Config.UseDNS = false;
      ipv6AcceptRAConfig.UseDNS = false;
      matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan1.mac;
      networkConfig = {
        IPv6PrivacyExtensions = "yes";
        MulticastDNS = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
    "10-wlan1" = {
      address = [
        (lib.net.cidr.hostCidr 1 iotCidrv4)
        (lib.net.cidr.hostCidr 1 iotCidrv6)
      ];
      matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wlan1.mac;
      networkConfig = {
        IPForward = "yes";
        IPv6PrivacyExtensions = "yes";
        IPv6SendRA = true;
        MulticastDNS = true;
      };
      # Announce a static prefix
      ipv6Prefixes = [
        {ipv6PrefixConfig.Prefix = iotCidrv6;}
      ];
      linkConfig.RequiredForOnline = "no";
    };
  };

  # TODO mkForce nftables
  networking.nftables.firewall = {
    zones = lib.mkForce {
      untrusted.interfaces = ["lan1"];
    };
  };
}
