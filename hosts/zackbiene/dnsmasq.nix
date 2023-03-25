{
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    extraConfig = ''
      interface=wlan1

      dhcp-authoritative
      dhcp-range=10.0.90.10,10.0.90.240,24h
      dhcp-range=fd90::10,fd90::ff0,24h

      enable-ra
      # Never forward addresses in the non-routed address spaces.
      bogus-priv

      no-resolv
    '';
  };
}
