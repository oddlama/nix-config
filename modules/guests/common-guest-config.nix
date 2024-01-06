_guestName: guestCfg: {
  config,
  lib,
  ...
}: let
  inherit (lib) mkForce;
in {
  node.name = guestCfg.nodeName;
  node.type = guestCfg.backend;

  # Set early hostname too, so we can associate those logs to this host and don't get "localhost" entries in loki
  boot.kernelParams = lib.mkIf (!config.boot.isContainer) [
    "systemd.hostname=${config.networking.hostName}"
  ];

  nix = {
    settings.auto-optimise-store = mkForce false;
    optimise.automatic = mkForce false;
    gc.automatic = mkForce false;
  };

  systemd.network.networks."10-${guestCfg.networking.mainLinkName}" = {
    matchConfig.Name = guestCfg.networking.mainLinkName;
    DHCP = "yes";
    dhcpV4Config.UseDNS = false;
    dhcpV6Config.UseDNS = false;
    ipv6AcceptRAConfig.UseDNS = false;
    networkConfig = {
      IPv6PrivacyExtensions = "yes";
      MulticastDNS = true;
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
  };

  networking.nftables.firewall = {
    zones.untrusted.interfaces = [guestCfg.networking.mainLinkName];
  };
}
