{
  config,
  globals,
  ...
}: let
  kanidmDomain = "auth.${globals.domains.me}";
  kanidmPort = 8300;

  mkRandomSecret = {
    generator.script = "alnum";
    mode = "440";
    group = "kanidm";
  };
in {
  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [kanidmPort];
  };

  age.secrets."kanidm-self-signed.crt" = {
    rekeyFile = config.node.secretsDir + "/kanidm-self-signed.crt.age";
    mode = "440";
    group = "kanidm";
  };

  age.secrets."kanidm-self-signed.key" = {
    rekeyFile = config.node.secretsDir + "/kanidm-self-signed.key.age";
    mode = "440";
    group = "kanidm";
  };

  age.secrets.kanidm-admin-password = mkRandomSecret;
  age.secrets.kanidm-idm-admin-password = mkRandomSecret;

  age.secrets.kanidm-oauth2-forgejo = mkRandomSecret;
  age.secrets.kanidm-oauth2-grafana = mkRandomSecret;
  age.secrets.kanidm-oauth2-immich = mkRandomSecret;
  age.secrets.kanidm-oauth2-paperless = mkRandomSecret;
  age.secrets.kanidm-oauth2-web-sentinel = mkRandomSecret;

  globals.services.kanidm.domain = kanidmDomain;
  globals.monitoring.http.kanidm = {
    url = "https://${kanidmDomain}/status";
    network = "internet";
    expectedBodyRegex = "true";
    skipTlsVerification = true;
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams.kanidm = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:${toString kanidmPort}" = {};
        extraConfig = ''
          zone kanidm 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          path = "/status";
          expectedBodyRegex = "true";
          skipTlsVerification = true;
          useHttps = true;
        };
      };
      virtualHosts.${kanidmDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/".proxyPass = "https://kanidm";
        # Allow using self-signed certs to satisfy kanidm's requirement
        # for TLS connections. (Although this is over wireguard anyway)
        extraConfig = ''
          proxy_ssl_verify off;
        '';
      };
    };
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/kanidm";
      user = "kanidm";
      group = "kanidm";
      mode = "0700";
    }
  ];

  services.kanidm = {
    enableServer = true;
    serverSettings = {
      domain = kanidmDomain;
      origin = "https://${kanidmDomain}";
      tls_chain = config.age.secrets."kanidm-self-signed.crt".path;
      tls_key = config.age.secrets."kanidm-self-signed.key".path;
      bindaddress = "0.0.0.0:${toString kanidmPort}";
      trust_x_forward_for = true;
    };

    enableClient = true;
    clientSettings = {
      uri = config.services.kanidm.serverSettings.origin;
      verify_ca = true;
      verify_hostnames = true;
    };

    provision = {
      enable = true;
      adminPasswordFile = config.age.secrets.kanidm-admin-password.path;
      idmAdminPasswordFile = config.age.secrets.kanidm-idm-admin-password.path;

      inherit (globals.kanidm) persons;

      # Immich
      groups."immich.access" = {};
      systems.oauth2.immich = {
        displayName = "Immich";
        originUrl = "https://${globals.services.immich.domain}/";
        basicSecretFile = config.age.secrets.kanidm-oauth2-immich.path;
        preferShortUsername = true;
        # XXX: PKCE is currently not supported by immich
        allowInsecureClientDisablePkce = true;
        # XXX: RS256 is used instead of ES256 so additionally we need legacy crypto
        enableLegacyCrypto = true;
        scopeMaps."immich.access" = ["openid" "email" "profile"];
      };

      # Netbird
      groups."netbird.access" = {};
      systems.oauth2.netbird = {
        public = true;
        displayName = "Netbird";
        originUrl = "https://${globals.services.netbird.domain}/";
        preferShortUsername = true;
        enableLocalhostRedirects = true;
        enableLegacyCrypto = true;
        scopeMaps."netbird.access" = ["openid" "email" "profile"];
      };

      # Paperless
      groups."paperless.access" = {};
      systems.oauth2.paperless = {
        displayName = "Paperless";
        originUrl = "https://${globals.services.paperless.domain}/";
        basicSecretFile = config.age.secrets.kanidm-oauth2-paperless.path;
        preferShortUsername = true;
        scopeMaps."paperless.access" = ["openid" "email" "profile"];
      };

      # Grafana
      groups."grafana.access" = {};
      groups."grafana.editors" = {};
      groups."grafana.admins" = {};
      groups."grafana.server-admins" = {};
      systems.oauth2.grafana = {
        displayName = "Grafana";
        originUrl = "https://${globals.services.grafana.domain}/";
        basicSecretFile = config.age.secrets.kanidm-oauth2-grafana.path;
        preferShortUsername = true;
        scopeMaps."grafana.access" = ["openid" "email" "profile"];
        claimMaps.groups = {
          joinType = "array";
          valuesByGroup = {
            "grafana.editors" = ["editor"];
            "grafana.admins" = ["admin"];
            "grafana.server-admins" = ["server_admin"];
          };
        };
      };

      # Forgejo
      groups."forgejo.access" = {};
      groups."forgejo.admins" = {};
      systems.oauth2.forgejo = {
        displayName = "Forgejo";
        originUrl = "https://${globals.services.forgejo.domain}/";
        basicSecretFile = config.age.secrets.kanidm-oauth2-forgejo.path;
        scopeMaps."forgejo.access" = ["openid" "email" "profile"];
        # XXX: PKCE is currently not supported by gitea/forgejo,
        # see https://github.com/go-gitea/gitea/issues/21376.
        allowInsecureClientDisablePkce = true;
        preferShortUsername = true;
        claimMaps.groups = {
          joinType = "array";
          valuesByGroup."forgejo.admins" = ["admin"];
        };
      };

      # Web Sentinel
      groups."web-sentinel.access" = {};
      groups."web-sentinel.adguardhome" = {};
      groups."web-sentinel.openwebui" = {};
      systems.oauth2.web-sentinel = {
        displayName = "Web Sentinel";
        originUrl = "https://oauth2.${globals.domains.me}/";
        basicSecretFile = config.age.secrets.kanidm-oauth2-web-sentinel.path;
        preferShortUsername = true;
        scopeMaps."web-sentinel.access" = ["openid" "email"];
        claimMaps.groups = {
          joinType = "array";
          valuesByGroup."web-sentinel.adguardhome" = ["access_adguardhome"];
          valuesByGroup."web-sentinel.openwebui" = ["access_openwebui"];
        };
      };
    };
  };

  systemd.services.kanidm.serviceConfig.RestartSec = "60"; # Retry every minute
}
