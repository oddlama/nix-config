{ config, ... }:
{
  networking.hostId = config.repo.secrets.local.networking.hostId;

  boot.initrd.systemd.network = {
    enable = true;
    networks = {
      inherit (config.systemd.network.networks) "10-lan";
    };
  };

  # This host sits in a separate apartment behind its own router, in a flat LAN
  # without any of the home vlans. Its address comes from the router via DHCP.
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "lan";
    DHCP = "yes";
    networkConfig.IPv6PrivacyExtensions = "yes";
    # The thread border router enables forwarding globally, which makes networkd
    # ignore RAs by default. We still want SLAAC and routes from the router.
    networkConfig.IPv6AcceptRA = true;
    linkConfig.RequiredForOnline = "routable";
  };

  networking.nftables.firewall = {
    zones.untrusted.interfaces = [ "lan" ];

    # Allow devices to be discovered through various protocols
    rules.discovery-protocols = {
      from = [ "untrusted" ];
      to = [ "local" ];
      allowedUDPPorts = [
        1900 # Simple Service Discovery Protocol, UPnP
      ];
      allowedTCPPorts = [
        40000 # UPnP HTTP
      ];
      # HomeKit etc. may use random high-numbered ports.
      # There's probably a better way to handle this
      allowedUDPPortRanges = [
        {
          from = 30000;
          to = 65535;
        }
      ];
    };
  };
}
