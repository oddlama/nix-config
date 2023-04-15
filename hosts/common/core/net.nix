{
  lib,
  pkgs,
  nodeName,
  nodeSecrets,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    mapAttrsToList
    mkDefault
    mkForce
    ;
in {
  networking = {
    hostName = mkDefault nodeName;
    useDHCP = mkForce false;
    useNetworkd = true;
    wireguard.enable = true;
    dhcpcd.enable = false;
    nftables.enable = true;
    firewall.enable = true;
  };

  # Rename known network interfaces
  services.udev.packages = let
    interfaceNamesUdevRules = pkgs.writeTextFile {
      name = "interface-names-udev-rules";
      text = concatStringsSep "\n" (mapAttrsToList (
          interface: attrs: ''SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="${attrs.mac}", NAME:="${interface}"''
        )
        nodeSecrets.networking.interfaces);
      destination = "/etc/udev/rules.d/01-interface-names.rules";
    };
  in [interfaceNamesUdevRules];

  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;
  };
}
