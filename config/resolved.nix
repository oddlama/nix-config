{
  services.resolved = {
    enable = true;
    dnssec = "false"; # NOTE: wake me up in 20 years when DNSSEC is at least partially working
    fallbackDns = [
      "1.1.1.1"
      "2606:4700:4700::1111"
      "8.8.8.8"
      "2001:4860:4860::8844"
    ];
    llmnr = "false";
    extraConfig = ''
      Domains=~.
    '';
  };
}
