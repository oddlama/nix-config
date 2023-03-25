{
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      interface = "wlan1";
      dhcp-authoritative = true;
      dhcp-range = [
        "10.0.90.10,10.0.90.240,24h"
        "fd90::10,fd90::ff0,24h"
      ];

      # Enable ipv6 router advertisements
      enable-ra = true;
      # Don't use anything from /etc/resolv.conf
      no-resolv = true;
      # Never forward addresses in the non-routed address spaces.
      bogus-priv = true;
    };
  };
}
