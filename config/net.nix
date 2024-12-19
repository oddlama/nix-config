{
  config,
  lib,
  ...
}:
{
  systemd.network.enable = true;
  systemd.network.wait-online.enable = false;

  networking = {
    useDHCP = lib.mkForce false;
    useNetworkd = true;
    dhcpcd.enable = false;

    # Rename known network interfaces from local secrets
    renameInterfacesByMac = lib.mapAttrs (_: v: v.mac) (
      config.repo.secrets.local.networking.interfaces or { }
    );
  };
}
