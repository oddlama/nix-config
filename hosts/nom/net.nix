{ config, ... }:
let
  lan1 = {
    DHCP = "yes";
    matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan1.mac;
    networkConfig.IPv6PrivacyExtensions = true;
  };
in
{
  networking = {
    inherit (config.repo.secrets.local.networking) hostId;

    # NetworkManager (with wpa_supplicant) instead of iwd + networkd, so that
    # UniFi Endpoint can provision WiFi and wired 802.1X connections.
    # systemd-networkd stays enabled from the base config but no longer
    # manages lan1 or wlan1.
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      connectionConfig."ipv6.ip6-privacy" = 2;
    };
    # Probes every serial device, which interferes with flashing dev boards.
    modemmanager.enable = false;
  };

  # Only used in the initrd, where NetworkManager isn't available
  boot.initrd.systemd.network = {
    enable = true;
    networks."10-lan1" = lan1;
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/etc/NetworkManager/system-connections";
      mode = "0700";
    }
  ];
  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/NetworkManager";
      mode = "0700";
    }
  ];

  networking.nftables.firewall = {
    zones.untrusted.interfaces = [
      "lan1"
      "wlan1"
    ];
  };
}
