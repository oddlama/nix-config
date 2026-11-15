{
  # Holds the Thread network dataset and keys. Losing this creates a new
  # Thread network and every Thread device has to be re-paired.
  environment.persistence."/persist".directories = [
    "/var/lib/thread"
  ];

  # Sonoff Dongle Plus MG24 running the Nerivec OpenThread RCP firmware
  # (3.1.2.0, 460800 baud, no hardware flow control on this board).
  # The other MG24 stick (...1ca130d1f7a2ef1184eb8a6661ce3355) runs the
  # Zigbee NCP firmware (EZSP 9.1.2.0, 460800 baud) and is set up in ZHA.
  # NOTE: this enables ipv4/ipv6 forwarding globally. The forward chain
  # still drops everything except lan-to-thread below.
  services.openthread-border-router = {
    enable = true;
    backboneInterfaces = [ "lan" ];
    radio = {
      device = "/dev/serial/by-id/usb-SONOFF_SONOFF_Dongle_Plus_MG24_def1edff3cf5ef119940a0a29ed47d52-if00-port0";
      baudRate = 460800;
      flowControl = false;
    };
  };

  # Unlike at home, there is no router that needs to know the Thread prefix. The border
  # router advertises a route to it in the flat LAN, and replies to the LAN are on-link.
  networking.nftables.firewall = {
    zones.thread.interfaces = [ "wpan0" ];

    rules = {
      thread-to-local = {
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

      # Let phones in the LAN reach Thread devices directly, which Android's
      # Matter commissioning needs. Replies are covered by conntrack.
      lan-to-thread = {
        from = [ "untrusted" ];
        to = [ "thread" ];
        verdict = "accept";
      };
    };
  };
}
