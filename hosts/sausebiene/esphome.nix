{
  config,
  globals,
  ...
}:
let
  esphomeDomain = "esphome.${globals.domains.personal}";
in
{
  wireguard.proxy-home.firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [
    config.services.esphome.port
  ];

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/esphome";
      mode = "0700";
    }
  ];

  globals.services.esphome.domain = esphomeDomain;
  # globals.monitoring.http.esphome = {
  #   url = "https://${esphomeDomain}";
  #   expectedBodyRegex = "esphome";
  #   network = "internet";
  # };

  topology.self.services.esphome.info = "https://${esphomeDomain}";
  services.esphome = {
    enable = true;
    address = "0.0.0.0";
    port = 3001;
  };

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams."esphome" = {
        servers."${config.wireguard.proxy-home.ipv4}:${toString config.services.esphome.port}" = { };
        extraConfig = ''
          zone esphome 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${esphomeDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://esphome";
          proxyWebsockets = true;
        };
        extraConfig = ''
          allow ${globals.net.home-lan.vlans.home.cidrv4};
          allow ${globals.net.home-lan.vlans.home.cidrv6};
          deny all;
        '';
      };
    };
  };
}
