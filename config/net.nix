{
  config,
  lib,
  ...
}:
{
  systemd.network.enable = true;
  systemd.network.wait-online.enable = false;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
    settings = {
      server = {
        use-ipv4 = true;
        use-ipv6 = true;
      };
      publish = {
        disable-publishing = false;
        publish-addresses = true;
      };
    };
  };

  networking = {
    useDHCP = lib.mkForce false;
    useNetworkd = true;
    dhcpcd.enable = false;

    # Rename known network interfaces from local secrets
    renameInterfacesByMac = lib.mapAttrs (_: v: v.mac) (
      config.repo.secrets.local.networking.interfaces or { }
    );

    nftables.chains.input.mdns = {
      after = [ "conntrack" ];
      rules = [ "udp dport 5353 accept" ];
    };
  };
}
