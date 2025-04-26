{
  config,
  globals,
  nodes,
  ...
}:
let
  fireflyDomain = "firefly.${globals.domains.me}";
  wardWebProxyCfg = nodes.ward-web-proxy.config;
in
{
  wireguard.proxy-home = {
    client.via = "ward";
    firewallRuleForNode.sausebiene.allowedTCPPorts = [ 80 ];
  };

  globals.services.firefly.domain = fireflyDomain;
  globals.monitoring.http.firefly = {
    url = "https://${fireflyDomain}";
    expectedBodyRegex = "Firefly-III";
    network = "home-lan.vlans.services";
  };

  age.secrets.firefly-app-key = {
    generator.script = _: ''
      echo "base64:$(head -c 32 /dev/urandom | base64)"
    '';
    owner = "firefly-iii";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/firefly-iii";
      user = "firefly-iii";
    }
  ];

  i18n.supportedLocales = [ "all" ];
  services.firefly-iii = {
    enable = true;
    enableNginx = true;
    virtualHost = globals.services.firefly.domain;
    settings = {
      APP_URL = "https://${globals.services.firefly.domain}";
      TZ = "Europe/Berlin";
      TRUSTED_PROXIES = wardWebProxyCfg.wireguard.proxy-home.ipv4;
      SITE_OWNER = "admin@${globals.domains.me}";
      APP_KEY_FILE = config.age.secrets.firefly-app-key.path;
      AUTHENTICATION_GUARD = "remote_user_guard";
      AUTHENTICATION_GUARD_HEADER = "X-User";
      AUTHENTICATION_GUARD_EMAIL = "X-Email";
    };
  };

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams.firefly = {
        servers."${config.wireguard.proxy-home.ipv4}:80" = { };
        extraConfig = ''
          zone firefly 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "Firefly";
        };
      };
      virtualHosts.${fireflyDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://firefly";
          proxyWebsockets = true;
        };
        extraConfig = ''
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
