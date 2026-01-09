{
  config,
  globals,
  ...
}:
let
  partdbDomain = "part-db.${globals.domains.me}";
in
{
  microvm.mem = 1024 * 3;
  microvm.vcpu = 4;

  globals.wireguard.proxy-home.hosts.${config.node.name}.firewallRuleForNode.ward-web-proxy.allowedTCPPorts =
    [ 80 ];

  globals.services.part-db.domain = partdbDomain;
  globals.monitoring.http.part-db = {
    url = "https://${partdbDomain}";
    expectedBodyRegex = "<title>Part-DB";
    network = "internet";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/part-db";
      user = "part-db";
      group = "part-db";
      mode = "0750";
    }
  ];

  services.part-db = {
    enable = true;
    enablePostgresql = true;
    enableNginx = true;
    virtualHost = "0.0.0.0";
    settings = {
      DEFAULT_LANG = "en";
      DEFAULT_TIMEZONE = "Europe/Berlin";
      BASE_CURRENCY = "EUR";
      BANNER = "Achtarmig reinlöten";
    };
  };

  services.nginx = {
    enable = true;
    recommendedSetup = false;
  };

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams.part-db = {
        servers."${globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4}:80" = { };
        extraConfig = ''
          zone part-db 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "<title>Part-DB";
        };
      };
      virtualHosts.${partdbDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://part-db";
          proxyWebsockets = true;
          X-Frame-Options = "SAMEORIGIN";
        };
        extraConfig = ''
          client_max_body_size 128M;
          allow ${globals.net.home-lan.vlans.home.cidrv4};
          allow ${globals.net.home-lan.vlans.home.cidrv6};
          # Firezone traffic
          allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv4};
          allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv6};
          deny all;
        '';
      };
    };
  };
}
