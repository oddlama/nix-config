{
  config,
  nodes,
  ...
}: let
  inherit (config.repo.secrets.global) domains;
  sentinelCfg = nodes.sentinel.config;
  kanidmDomain = "auth.${domains.me}";
  kanidmPort = 8300;

  mkRandomSecret = {
    generator.script = "alnum";
    mode = "440";
    group = "kanidm";
  };
in {
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [kanidmPort];

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

  nodes.sentinel = {
    networking.providedDomains.kanidm = kanidmDomain;

    services.nginx = {
      upstreams.kanidm = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:${toString kanidmPort}" = {};
        extraConfig = ''
          zone kanidm 64k;
          keepalive 2;
        '';
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

      inherit (config.repo.secrets.global.kanidm) persons;

      # Immich
      groups."immich.access" = {};
      systems.oauth2.immich = {
        displayName = "Immich";
        originUrl = "https://${sentinelCfg.networking.providedDomains.immich}/";
        basicSecretFile = config.age.secrets.kanidm-oauth2-immich.path;
        preferShortUsername = true;
        # XXX: PKCE is currently not supported by immich
        # XXX: Also RS256 is used instead of ES256 so additionally needed:
        # kanidm system oauth2 warning-enable-legacy-crypto immich
        allowInsecureClientDisablePkce = true;
        scopeMaps."immich.access" = ["openid" "email" "profile"];
      };

      # Paperless
      groups."paperless.access" = {};
      systems.oauth2.paperless = {
        displayName = "Paperless";
        originUrl = "https://${sentinelCfg.networking.providedDomains.paperless}/";
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
        originUrl = "https://${sentinelCfg.networking.providedDomains.grafana}/";
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
        originUrl = "https://${sentinelCfg.networking.providedDomains.forgejo}/";
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
      groups."web-sentinel.influxdb" = {};
      systems.oauth2.web-sentinel = {
        displayName = "Web Sentinel";
        originUrl = "https://oauth2.${domains.me}/";
        basicSecretFile = config.age.secrets.kanidm-oauth2-web-sentinel.path;
        preferShortUsername = true;
        scopeMaps."web-sentinel.access" = ["openid" "email"];
        claimMaps.groups = {
          joinType = "array";
          valuesByGroup."web-sentinel.adguardhome" = ["access_adguardhome"];
          valuesByGroup."web-sentinel.influxdb" = ["access_influxdb"];
        };
      };
    };
  };

  systemd.services.kanidm.serviceConfig.RestartSec = "60"; # Retry every minute
}
