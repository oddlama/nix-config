{
  # Holds the Thread network dataset and keys. Losing this creates a new
  # Thread network and every Thread device has to be re-paired.
  environment.persistence."/persist".directories = [
    "/var/lib/thread"
  ];

  # Sonoff Dongle Plus MG24 running the Nerivec OpenThread RCP firmware
  # (2.7.2.0, 460800 baud, no hardware flow control on this board).
  # NOTE: this enables ipv4/ipv6 forwarding globally. The forward chain
  # still drops everything, so this does not route between our vlans.
  services.openthread-border-router = {
    enable = true;
    backboneInterfaces = [ "vlan-iot" ];
    radio = {
      device = "/dev/serial/by-id/usb-SONOFF_SONOFF_Dongle_Plus_MG24_4c9267d80d8cf011b0ff30b9d9065118-if00-port0";
      baudRate = 460800;
      flowControl = false;
    };
  };

  networking.nftables.firewall = {
    zones.thread.interfaces = [ "wpan0" ];
    rules.thread-to-local = {
      from = [ "thread" ];
      to = [ "local" ];
      # Thread devices answer the matter controller on its random high UDP port,
      # which may happen after the conntrack entry has already expired.
      allowedUDPPortRanges = [
        {
          from = 30000;
          to = 65535;
        }
      ];
    };
  };
}
