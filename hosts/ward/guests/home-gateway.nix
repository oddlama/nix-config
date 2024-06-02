{globals, ...}: {
  # Forwarding required to masquerade netbird network
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  wireguard.proxy-home.client.via = "ward";

  networking.nftables.chains.forward.from-netbird = {
    after = ["conntrack"];
    rules = [
      "iifname wt-home oifname lan accept"
    ];
  };

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
      NB_MANAGEMENT_URL = "https://${globals.services.netbird.domain}";
      NB_ADMIN_URL = NB_MANAGEMENT_URL;
      NB_HOSTNAME = "home-gateway";
    };
  };
}
