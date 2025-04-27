{
  config,
  globals,
  nodes,
  ...
}:
let
  fireflyDomain = "firefly.${globals.domains.me}";
  fireflyPicoDomain = "firefly-pico.${globals.domains.me}";
  fireflyDataImporterDomain = "firefly-data-importer.${globals.domains.me}";
  wardWebProxyCfg = nodes.ward-web-proxy.config;
in
{
  wireguard.proxy-home = {
    client.via = "ward";
    firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [ 80 ];
  };

  globals.services.firefly.domain = fireflyDomain;
  globals.services.firefly-pico.domain = fireflyPicoDomain;
  globals.services.firefly-data-importer.domain = fireflyDataImporterDomain;
  globals.monitoring.http.firefly = {
    url = "https://${fireflyDomain}";
    expectedBodyRegex = "Firefly III";
    network = "home-lan.vlans.services";
  };
  globals.monitoring.http.firefly-pico = {
    url = "https://${fireflyPicoDomain}";
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
    owner = "firefly-pico";
  };

  age.secrets.firefly-data-importer-app-key = {
    generator.script = _: ''
      echo "base64:$(head -c 32 /dev/urandom | base64)"
    '';
    owner = "firefly-data-importer";
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
    {
      directory = "/var/lib/firefly-iii-data-importer";
      user = "firefly-iii-data-importer";
    }
  ];

  networking.hosts.${wardWebProxyCfg.wireguard.proxy-home.ipv4} = [
    globals.services.firefly.domain
    globals.services.firefly-pico.domain
  ];

  i18n.supportedLocales = [ "all" ];
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
    virtualHost = globals.services.firefly-pico.domain;
    settings = {
      LOG_CHANNEL = "syslog";
      APP_URL = "https://${globals.services.firefly-pico.domain}";
      TZ = "Europe/Berlin";
      FIREFLY_URL = config.services.firefly-iii.settings.APP_URL;
      TRUSTED_PROXIES = wardWebProxyCfg.wireguard.proxy-home.ipv4;
      SITE_OWNER = "admin@${globals.domains.me}";
      APP_KEY_FILE = config.age.secrets.firefly-pico-app-key.path;
    };
  };

  services.firefly-iii-data-importer = {
    enable = true;
    enableNginx = true;
    virtualHost = globals.services.firefly-data-importer.domain;
    settings = {
      LOG_CHANNEL = "syslog";
      APP_ENV = "local";
      APP_URL = "https://${globals.services.firefly-data-importer.domain}";
      TZ = "Europe/Berlin";
      FIREFLY_III_URL = config.services.firefly-iii.settings.APP_URL;
      VANITY_URL = config.services.firefly-iii.settings.APP_URL;
      TRUSTED_PROXIES = wardWebProxyCfg.wireguard.proxy-home.ipv4;
      EXPECT_SECURE_URL = "true";
      APP_KEY_FILE = config.age.secrets.firefly-data-importer-app-key.path;
    };
  };

  services.nginx.commonHttpConfig = ''
    log_format json_combined escape=json '{'
      '"time": $msec,'
      '"remote_addr":"$remote_addr",'
      '"status":$status,'
      '"method":"$request_method",'
      '"host":"$host",'
      '"uri":"$request_uri",'
      '"request_size":$request_length,'
      '"response_size":$body_bytes_sent,'
      '"response_time":$request_time,'
      '"referrer":"$http_referer",'
      '"user_agent":"$http_user_agent"'
    '}';
    error_log syslog:server=unix:/dev/log,nohostname;
    access_log syslog:server=unix:/dev/log,nohostname json_combined;
    ssl_ecdh_curve secp384r1;
  '';

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
          # allow self-access
          allow ${config.wireguard.proxy-home.ipv4};
          allow ${config.wireguard.proxy-home.ipv6};
          # allow home traffic
          allow ${globals.net.home-lan.vlans.home.cidrv4};
          allow ${globals.net.home-lan.vlans.home.cidrv6};
          # Firezone traffic
          allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv4};
          allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv6};
          deny all;
        '';
      };
      virtualHosts.${fireflyPicoDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://firefly";
          proxyWebsockets = true;
        };
        extraConfig = ''
          # allow self-access
          allow ${config.wireguard.proxy-home.ipv4};
          allow ${config.wireguard.proxy-home.ipv6};
          # allow home traffic
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
