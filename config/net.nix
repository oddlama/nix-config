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
    ipv4 = true;
    ipv6 = true;
    nssmdns4 = true;
    nssmdns6 = true;
    publish = {
      enable = true;
      addresses = true;
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
