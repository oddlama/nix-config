{config, ...}: {
  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    settings = {
      DATA_FOLDER = "/var/lib/vaultwarden";
      EXTENDED_LOGGING = true;
      USE_SYSLOG = true;
      WEB_VAULT_ENABLED = true;

      WEBSOCKET_ENABLED = true;
      WEBSOCKET_ADDRESS = "127.0.0.1";
      WEBSOCKET_PORT = 3012;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8012;

      SIGNUPS_ALLOWED = false;
      PASSWORD_ITERATIONS = 1000000;
      INVITATIONS_ALLOWED = true;
      INVITATION_ORG_NAME = "Vaultwarden";
      DOMAIN = config.repo.secrets.local.vaultwarden.domain;

      SMTP_EMBED_IMAGES = true;
    };
    #backupDir = "/data/backup";
    #YUBICO_CLIENT_ID=;
    #YUBICO_SECRET_KEY=;
    #ADMIN_TOKEN="$argon2id:TODO";
    #SMTP_HOST={{ vaultwarden_smtp_host }};
    #SMTP_FROM={{ vaultwarden_smtp_from }};
    #SMTP_FROM_NAME={{ vaultwarden_smtp_from_name }};
    #SMTP_PORT = 465;
    #SMTP_SECURITY = "force_tls";
    #SMTP_USERNAME={{ vaultwarden_smtp_username }};
    #SMTP_PASSWORD={{ vaultwarden_smtp_password }};
    #environmentFile = config.rekey.secrets.vaultwarden-env.path;
  };

  # Replace uses of old name
  systemd.services.vaultwarden.seviceConfig.StateDirectory = "vaultwarden";
  systemd.services.backup-vaultwarden.environment.DATA_FOLDER = "/var/lib/vaultwarden";

  services.nginx = {
    upstreams."vaultwarden" = {
      servers."localhost:8012" = {};
      extraConfig = ''
        zone vaultwarden 64k;
        keepalive 2;
      '';
    };
    upstreams."vaultwarden-websocket" = {
      servers."localhost:3012" = {};
      extraConfig = ''
        zone vaultwarden-websocket 64k;
        keepalive 2;
      '';
    };
    virtualHosts."${config.repo.secrets.local.vaultwarden.domain}" = {
      forceSSL = true;
      #enableACME = true;
      sslCertificate = config.rekey.secrets."selfcert.crt".path;
      sslCertificateKey = config.rekey.secrets."selfcert.key".path;
      locations."/" = {
        proxyPass = "http://vaultwarden";
        proxyWebsockets = true;
      };
      locations."/notifications/hub" = {
        proxyPass = "http://vaultwarden-websocket";
        proxyWebsockets = true;
      };
      locations."/notifications/hub/negotiate" = {
        proxyPass = "http://vaultwarden";
        proxyWebsockets = true;
      };
    };
  };
}
