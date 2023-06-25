{
  config,
  lib,
  nodeName,
  nodes,
  utils,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  grafanaDomain = "grafana.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  imports = [
    ../../../../modules/proxy-via-sentinel.nix
  ];

  extra.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${sentinelCfg.extra.wireguard.proxy-sentinel.ipv4} = [sentinelCfg.providedDomains.influxdb];
  extra.telegraf = {
    enable = true;
    influxdb2.domain = sentinelCfg.providedDomains.influxdb;
    influxdb2.organization = "servers";
    influxdb2.bucket = "telegraf";
  };

  networking.nftables.firewall.rules = lib.mkForce {
    sentinel-to-local.allowedTCPPorts = [config.services.grafana.settings.server.http_port];
  };

  age.secrets.grafana-secret-key = {
    rekeyFile = ./secrets/grafana-secret-key.age;
    mode = "440";
    group = "grafana";
  };

  age.secrets.grafana-loki-basic-auth-password = {
    rekeyFile = ./secrets/grafana-loki-basic-auth-password.age;
    generator = "alnum";
    mode = "440";
    group = "grafana";
  };

  age.secrets.grafana-influxdb-token = {
    rekeyFile = ./secrets/grafana-influxdb-token.age;
    mode = "440";
    group = "grafana";
  };

  nodes.sentinel = {
    age.secrets.loki-basic-auth-hashes.generator.dependencies = [
      config.age.secrets.grafana-loki-basic-auth-password
    ];

    providedDomains.grafana = grafanaDomain;

    services.nginx = {
      upstreams.grafana = {
        servers."${config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}" = {};
        extraConfig = ''
          zone grafana 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${grafanaDomain} = {
        forceSSL = true;
        useACMEHost = sentinelCfg.lib.extra.matchingWildcardCert grafanaDomain;
        locations."/" = {
          proxyPass = "http://grafana";
          proxyWebsockets = true;
        };
      };
    };
  };

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
        http_addr = config.extra.wireguard.proxy-sentinel.ipv4;
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
        #client_secret = "$__file{${config.age.secrets.grafana-oauth-client-secret.path}}";
        client_secret = "aZKNCM6KpjBy4RqwKJXMLXzyx9rKH6MZTFk4wYrKWuBqLj6t"; # TODO temporary test not a real secret
        scopes = "openid email profile";
        login_attribute_path = "prefered_username";
        auth_url = "https://${sentinelCfg.providedDomains.kanidm}/ui/oauth2";
        token_url = "https://${sentinelCfg.providedDomains.kanidm}/oauth2/token";
        api_url = "https://${sentinelCfg.providedDomains.kanidm}/oauth2/openid/grafana/userinfo";
        use_pkce = true;
        # Allow mapping oauth2 roles to server admin
        allow_assign_grafana_admin = true;
        role_attribute_path = "contains(scopes[*], 'server_admin') && 'GrafanaAdmin' || contains(scopes[*], 'admin') && 'Admin' || contains(scopes[*], 'editor') && 'Editor' || 'Viewer'";
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "InfluxDB (servers)";
          type = "influxdb";
          access = "proxy";
          url = "https://${sentinelCfg.providedDomains.influxdb}";
          orgId = 1;
          secureJsonData.token = "$__file{${config.age.secrets.grafana-influxdb-token.path}}";
          jsonData.version = "Flux";
          jsonData.organization = "servers";
          jsonData.defaultBucket = "telegraf";
        }
        # TODO duplicate above influxdb source (with scoped read tokens??) for each organization
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "https://${sentinelCfg.providedDomains.loki}";
          orgId = 1;
          basicAuth = true;
          basicAuthUser = "${nodeName}+grafana-loki-basic-auth-password";
          secureJsonData.basicAuthPassword = "$__file{${config.age.secrets.grafana-loki-basic-auth-password.path}}";
        }
      ];
    };
  };

  systemd.services.grafana.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "proxy-sentinel"}.device"];
}
