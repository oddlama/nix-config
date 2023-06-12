{
  config,
  lib,
  nodeName,
  nodes,
  utils,
  ...
}: {
  imports = [
    ../../../../modules/proxy-via-sentinel.nix
  ];

  networking.nftables.firewall.rules = lib.mkForce {
    sentinel-to-local.allowedTCPPorts = [3001];
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

  nodes.sentinel.age.secrets.loki-basic-auth-hashes.generator.dependencies = [
    config.age.secrets.grafana-loki-basic-auth-password
  ];

  services.grafana = {
    enable = true;
    settings = {
      analytics.reporting_enabled = false;
      users.allow_sign_up = false;

      server = {
        domain = nodes.sentinel.config.proxiedDomains.grafana;
        root_url = "https://${nodes.sentinel.config.proxiedDomains.grafana}";
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
        auto_login = true;
        client_id = "grafana";
        #client_secret = "$__file{${config.age.secrets.grafana-oauth-client-secret.path}}";
        client_secret = "r6Yk5PPSXFfYDPpK6TRCzXK8y1rTrfcb8F7wvNC5rZpyHTMF"; # TODO temporary test not a real secret
        scopes = "openid email profile";
        login_attribute_path = "prefered_username";
        auth_url = "https://${nodes.sentinel.config.proxiedDomains.kanidm}/ui/oauth2";
        token_url = "https://${nodes.sentinel.config.proxiedDomains.kanidm}/oauth2/token";
        api_url = "https://${nodes.sentinel.config.proxiedDomains.kanidm}/oauth2/openid/grafana/userinfo";
        use_pkce = true;
        # Allow mapping oauth2 roles to server admin
        allow_assign_grafana_admin = true;
        role_attribute_path = "contains(scopes[*], 'server_admin') && 'GrafanaAdmin' || contains(scopes[*], 'admin') && 'Admin' || contains(scopes[*], 'editor') && 'Editor' || 'Viewer'";
      };
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [
        #{
        #  name = "Prometheus";
        #  type = "prometheus";
        #  url = "http://127.0.0.1:9090";
        #  orgId = 1;
        #}
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "https://${nodes.sentinel.config.proxiedDomains.loki}";
          orgId = 1;
          basicAuth = true;
          basicAuthUser = nodeName;
          secureJsonData.basicAuthPassword = "$__file{${config.age.secrets.grafana-loki-basic-auth-password.path}}";
        }
      ];
    };
  };

  systemd.services.grafana.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "proxy-sentinel"}.device"];
}
