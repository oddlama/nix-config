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
    firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [ 80 ];
  };

  globals.services.firefly.domain = fireflyDomain;
  globals.monitoring.http.firefly = {
    url = "https://${fireflyDomain}";
    expectedBodyRegex = "Firefly III";
    network = "home-lan.vlans.services";
  };
  globals.monitoring.http.firefly-pico = {
    url = "https://${fireflyDomain}/pico";
    expectedBodyRegex = "Pico";
    network = "home-lan.vlans.services";
  };

  age.secrets.firefly-iii-app-key = {
    generator.script = _: ''
      echo "base64:$(head -c 32 /dev/urandom | base64)"
    '';
    owner = "firefly-iii";
  };

  age.secrets.firefly-pico-app-key = {
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
    {
      directory = "/var/lib/firefly-pico";
      user = "firefly-pico";
    }
  ];

  services.firefly-iii = {
    enable = true;
    enableNginx = true;
    virtualHost = globals.services.firefly.domain;
    settings = {
      AUDIT_LOG_LEVEL = "emergency"; # disable audit logs
      LOG_CHANNEL = "syslog";
      APP_URL = "https://${globals.services.firefly.domain}";
      TZ = "Europe/Berlin";
      TRUSTED_PROXIES = wardWebProxyCfg.wireguard.proxy-home.ipv4;
      SITE_OWNER = "admin@${globals.domains.me}";
      APP_KEY_FILE = config.age.secrets.firefly-iii-app-key.path;
    };
  };

  services.firefly-pico = {
    enable = true;
    enableNginx = true;
    virtualHost = "pico.internal";
    settings = {
      LOG_CHANNEL = "syslog";
      APP_URL = "https://${globals.services.firefly.domain}/pico";
      TZ = "Europe/Berlin";
      FIREFLY_URL = config.services.firefly-iii.settings.APP_URL;
      TRUSTED_PROXIES = wardWebProxyCfg.wireguard.proxy-home.ipv4;
      SITE_OWNER = "admin@${globals.domains.me}";
      APP_KEY_FILE = config.age.secrets.firefly-pico-app-key.path;
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
        locations."/pico" = {
          proxyPass = "http://firefly/"; # Trailing slash matters! (remove location suffix)
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host pico.internal;
          '';
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
