{
  config,
  lib,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  grafanaDomain = "grafana.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [config.services.grafana.settings.server.http_port];

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

  age.secrets.grafana-influxdb-token = {
    generator.script = "alnum";
    generator.tags = ["influxdb"];
    mode = "440";
    group = "grafana";
  };

  nodes.ward-influxdb = {
    # Mirror the original secret on the influx host
    age.secrets."grafana-influxdb-token-${config.node.name}" = {
      inherit (config.age.secrets.grafana-influxdb-token) rekeyFile;
      mode = "440";
      group = "influxdb2";
    };

    services.influxdb2.provision.ensureApiTokens = [
      {
        name = "grafana servers:telegraf (${config.node.name})";
        org = "servers";
        user = "admin";
        readBuckets = ["telegraf"];
        writeBuckets = ["telegraf"];
        tokenFile = nodes.ward-influxdb.config.age.secrets."grafana-influxdb-token-${config.node.name}".path;
      }
    ];
  };

  nodes.sentinel = {
    age.secrets.loki-basic-auth-hashes.generator.dependencies = [
      config.age.secrets.grafana-loki-basic-auth-password
    ];

    networking.providedDomains.grafana = grafanaDomain;

    services.nginx = {
      upstreams.grafana = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:${toString config.services.grafana.settings.server.http_port}" = {};
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
        #client_secret = "$__file{${config.age.secrets.grafana-oauth-client-secret.path}}";
        client_secret = "aZKNCM6KpjBy4RqwKJXMLXzyx9rKH6MZTFk4wYrKWuBqLj6t"; # TODO temporary test not a real secret
        scopes = "openid email profile";
        login_attribute_path = "prefered_username";
        auth_url = "https://${sentinelCfg.networking.providedDomains.kanidm}/ui/oauth2";
        token_url = "https://${sentinelCfg.networking.providedDomains.kanidm}/oauth2/token";
        api_url = "https://${sentinelCfg.networking.providedDomains.kanidm}/oauth2/openid/grafana/userinfo";
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
          url = "https://${sentinelCfg.networking.providedDomains.influxdb}";
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
          url = "https://${sentinelCfg.networking.providedDomains.loki}";
          orgId = 1;
          basicAuth = true;
          basicAuthUser = "${config.node.name}+grafana-loki-basic-auth-password";
          secureJsonData.basicAuthPassword = "$__file{${config.age.secrets.grafana-loki-basic-auth-password.path}}";
        }
      ];
    };
  };

  systemd.services.grafana.serviceConfig.RestartSec = "600"; # Retry every 10 minutes
}
