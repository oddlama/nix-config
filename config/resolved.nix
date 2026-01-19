{
  services.resolved = {
    enable = true;
    settings.Resolve = {
      MulticastDNS = false;
      DNSSEC = false; # NOTE: wake me up in 20 years when DNSSEC is at least partially working
      LLMNR = false;
      FallbackDNS = [
        "1.1.1.1"
        "2606:4700:4700::1111"
        "8.8.8.8"
        "2001:4860:4860::8844"
      ];
    };
  };
}
