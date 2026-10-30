{ globals, ... }:
let
  # Routing table for traffic leaving the Thread network towards the rest of the LAN
  threadReturnTable = 30;
in
{
  # Holds the Thread network dataset and keys. Losing this creates a new
  # Thread network and every Thread device has to be re-paired.
  environment.persistence."/persist".directories = [
    "/var/lib/thread"
  ];

  # Sonoff Dongle Plus MG24 running the Nerivec OpenThread RCP firmware
  # (2.7.2.0, 460800 baud, no hardware flow control on this board).
  # NOTE: this enables ipv4/ipv6 forwarding globally. The forward chain
  # still drops everything except home-to-thread below.
  services.openthread-border-router = {
    enable = true;
    backboneInterfaces = [ "vlan-iot" ];
    radio = {
      device = "/dev/serial/by-id/usb-SONOFF_SONOFF_Dongle_Plus_MG24_4c9267d80d8cf011b0ff30b9d9065118-if00-port0";
      baudRate = 460800;
      flowControl = false;
    };
  };

  # Ward routes the Thread prefix (globals.net.home-thread) to us via the iot vlan. Send
  # everything coming back out of the Thread network the same way, instead of via whichever
  # of our vlans holds the default route. Otherwise ward would see asymmetric replies.
  systemd.network.networks."30-vlan-iot" = {
    routingPolicyRules = [
      # Keep using the main table for anything more specific than a default route (on-link prefixes)
      {
        Family = "ipv6";
        Table = "main";
        SuppressPrefixLength = 0;
        Priority = 100;
      }
      {
        From = globals.net.home-thread.cidrv6;
        Table = threadReturnTable;
        Priority = 101;
      }
    ];
    routes = [
      {
        Gateway = globals.net.home-lan.vlans.iot.hosts.ward.ipv6;
        Table = threadReturnTable;
      }
    ];
  };

  networking.nftables.firewall = {
    zones = {
      thread.interfaces = [ "wpan0" ];
      home-lan.ipv6Addresses = [ globals.net.home-lan.vlans.home.cidrv6 ];
    };

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

      # Let phones in the home vlan reach Thread devices directly, which Android's
      # Matter commissioning needs. Replies are covered by conntrack.
      home-to-thread = {
        from = [ "home-lan" ];
        to = [ "thread" ];
        verdict = "accept";
      };
    };
  };
}
