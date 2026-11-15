{
  # There is no reverse proxy here, devices in the LAN access the web interface directly.
  # openFirewall below only opens the ports needed by the providers.
  networking.firewall.allowedTCPPorts = [ 8095 ];

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/music-assistant";
      mode = "0700";
    }
  ];

  services.music-assistant = {
    enable = true;
    openFirewall = true;
    providers = [
      "airplay"
      "builtin"
      "chromecast"
      "dlna"
      "hass"
      "hass_players"
      "opensubsonic"
      "radiobrowser"
      "sendspin"
      "spotify"
      "spotify_connect"
      "universal_group"
    ];
  };
}
