{nodes, ...}: {
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/netbird-home";
      mode = "0700";
    }
  ];

  services.netbird.clients.home = {
    port = 51820;
    name = "netbird-home";
    interface = "wt-home";
    openFirewall = true;
    config.ServerSSHAllowed = false;
    environment = rec {
      NB_MANAGEMENT_URL = "https://${nodes.sentinel.config.networking.providedDomains.netbird}";
      NB_ADMIN_URL = NB_MANAGEMENT_URL;
      NB_HOSTNAME = "home-gateway";
    };
  };
}
