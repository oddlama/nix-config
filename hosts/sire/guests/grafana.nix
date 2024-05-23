{
  config,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  wardWebProxyCfg = nodes.ward-web-proxy.config;
  grafanaDomain = "grafana.${config.repo.secrets.global.domains.me}";
in {
  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.grafana.settings.server.http_port];
  };

  wireguard.proxy-home = {
    client.via = "ward";
    firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [config.services.grafana.settings.server.http_port];
  };

  age.secrets.grafana-secret-key = {
    rekeyFile = config.node.secretsDir + "/grafana-secret-key.age";
    mode = "440";
    group = "grafana";
  };

  age.secrets.grafana-loki-basic-auth-password = {
    generator.script = "alnum";
    mode = "440";
    group = "grafana";
  };

  age.secrets.grafana-influxdb-token-machines = {
    generator.script = "alnum";
    generator.tags = ["influxdb"];
    mode = "440";
    group = "grafana";
  };

  age.secrets.grafana-influxdb-token-home = {
    generator.script = "alnum";
    generator.tags = ["influxdb"];
    mode = "440";
    group = "grafana";
  };

  # Mirror the original oauth2 secret
  age.secrets.grafana-oauth2-client-secret = {
    inherit (nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-grafana) rekeyFile;
    mode = "440";
    group = "grafana";
  };

  nodes.sire-influxdb = {
    # Mirror the original secret on the influx host
    age.secrets."grafana-influxdb-token-machines-${config.node.name}" = {
      inherit (config.age.secrets.grafana-influxdb-token-machines) rekeyFile;
      mode = "440";
      group = "influxdb2";
    };

    services.influxdb2.provision.organizations.machines.auths."grafana machines:telegraf (${config.node.name})" = {
      readBuckets = ["telegraf"];
      writeBuckets = ["telegraf"];
      tokenFile = nodes.sire-influxdb.config.age.secrets."grafana-influxdb-token-machines-${config.node.name}".path;
    };

    age.secrets."grafana-influxdb-token-home-${config.node.name}" = {
      inherit (config.age.secrets.grafana-influxdb-token-home) rekeyFile;
      mode = "440";
      group = "influxdb2";
    };

    services.influxdb2.provision.organizations.home.auths."grafana home:home_assistant (${config.node.name})" = {
      readBuckets = ["home_assistant"];
      writeBuckets = ["home_assistant"];
      tokenFile = nodes.sire-influxdb.config.age.secrets."grafana-influxdb-token-home-${config.node.name}".path;
    };
  };

  nodes.sentinel = {
    age.secrets.loki-basic-auth-hashes.generator.dependencies = [
      config.age.secrets.grafana-loki-basic-auth-password
    ];

    networking.providedDomains.grafana = grafanaDomain;

    services.nginx = {
      upstreams.grafana = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:${toString config.services.grafana.settings.server.http_port}" = {};
        extraConfig = ''
          zone grafana 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${grafanaDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://grafana";
          proxyWebsockets = true;
        };
      };
    };
  };

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams.grafana = {
        servers."${config.wireguard.proxy-home.ipv4}:${toString config.services.grafana.settings.server.http_port}" = {};
        extraConfig = ''
          zone grafana 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${grafanaDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://grafana";
          proxyWebsockets = true;
        };
        # FIXME: refer to lan 192.168... and fd10:: via globals
        extraConfig = ''
          allow 192.168.1.0/24;
          allow fd10::/64;
          deny all;
        '';
      };
    };
  };

  environment.persistence."/persist".directories = [
    {
      directory = config.services.grafana.dataDir;
      user = "grafana";
      group = "grafana";
      mode = "0700";
    }
  ];

  networking.hosts.${wardWebProxyCfg.wireguard.proxy-home.ipv4} = [
    sentinelCfg.networking.providedDomains.influxdb # technically a duplicate (see ./common.nix)...
    sentinelCfg.networking.providedDomains.loki
  ];

  services.grafana = {
    enable = true;
    settings = {
      analytics.reporting_enabled = false;
      users.allow_sign_up = false;

      server = {
        domain = grafanaDomain;
        root_url = "https://${grafanaDomain}";
        enforce_domain = true;
        enable_gzip = true;
        http_addr = "0.0.0.0";
        http_port = 3001;
      };

      security = {
        disable_initial_admin_creation = true;
        secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
        cookie_secure = true;
        disable_gravatar = true;
        hide_version = true;
      };

      auth.disable_login_form = true;
      "auth.generic_oauth" = {
        enabled = true;
        name = "Kanidm";
        icon = "signin";
        allow_sign_up = true;
        #auto_login = true;
        client_id = "grafana";
        client_secret = "$__file{${config.age.secrets.grafana-oauth2-client-secret.path}}";
        scopes = "openid email profile";
        login_attribute_path = "preferred_username";
        auth_url = "https://${sentinelCfg.networking.providedDomains.kanidm}/ui/oauth2";
        token_url = "https://${sentinelCfg.networking.providedDomains.kanidm}/oauth2/token";
        api_url = "https://${sentinelCfg.networking.providedDomains.kanidm}/oauth2/openid/grafana/userinfo";
        use_pkce = true;
        # Allow mapping oauth2 roles to server admin
        allow_assign_grafana_admin = true;
        role_attribute_path = "contains(groups[*], 'server_admin') && 'GrafanaAdmin' || contains(groups[*], 'admin') && 'Admin' || contains(groups[*], 'editor') && 'Editor' || 'Viewer'";
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "InfluxDB (machines)";
          type = "influxdb";
          access = "proxy";
          url = "https://${sentinelCfg.networking.providedDomains.influxdb}";
          orgId = 1;
          secureJsonData.token = "$__file{${config.age.secrets.grafana-influxdb-token-machines.path}}";
          jsonData.version = "Flux";
          jsonData.organization = "machines";
          jsonData.defaultBucket = "telegraf";
        }
        {
          name = "InfluxDB (home_assistant)";
          type = "influxdb";
          access = "proxy";
          url = "https://${sentinelCfg.networking.providedDomains.influxdb}";
          orgId = 1;
          secureJsonData.token = "$__file{${config.age.secrets.grafana-influxdb-token-home.path}}";
          jsonData.version = "Flux";
          jsonData.organization = "home";
          jsonData.defaultBucket = "home_assistant";
        }
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "https://${sentinelCfg.networking.providedDomains.loki}";
          orgId = 1;
          basicAuth = true;
          basicAuthUser = "${config.node.name}+grafana-loki-basic-auth-password";
          secureJsonData.basicAuthPassword = "$__file{${config.age.secrets.grafana-loki-basic-auth-password.path}}";
        }
      ];
    };
  };

  systemd.services.grafana.serviceConfig.RestartSec = "60"; # Retry every minute
}
