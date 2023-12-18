{
  config,
  lib,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  vaultwardenDomain = "pw.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [
    config.services.vaultwarden.config.rocketPort
    config.services.vaultwarden.config.websocketPort
  ];

  age.secrets.vaultwarden-env = {
    rekeyFile = config.node.secretsDir + "/vaultwarden-env.age";
    mode = "440";
    group = "vaultwarden";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/vaultwarden";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "0700";
    }
  ];

  nodes.sentinel = {
    networking.providedDomains.vaultwarden = vaultwardenDomain;

    services.nginx = {
      upstreams.vaultwarden = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:${toString config.services.vaultwarden.config.rocketPort}" = {};
        extraConfig = ''
          zone vaultwarden 64k;
          keepalive 2;
        '';
      };
      upstreams.vaultwarden-websocket = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:${toString config.services.vaultwarden.config.websocketPort}" = {};
        extraConfig = ''
          zone vaultwarden-websocket 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${vaultwardenDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        extraConfig = ''
          client_max_body_size 256M;
        '';
        locations."/".proxyPass = "http://vaultwarden";
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
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    config = {
      dataFolder = lib.mkForce "/var/lib/vaultwarden";
      extendedLogging = true;
      useSyslog = true;
      webVaultEnabled = true;

      websocketEnabled = true;
      websocketAddress = "0.0.0.0";
      websocketPort = 3012;
      rocketAddress = "0.0.0.0";
      rocketPort = 8012;

      signupsAllowed = false;
      passwordIterations = 1000000;
      invitationsAllowed = true;
      invitationOrgName = "Vaultwarden";
      domain = "https://${vaultwardenDomain}";

      smtpEmbedImages = true;
      smtpSecurity = "force_tls";
      smtpPort = 465;
    };
    #backupDir = "/data/backup";
    environmentFile = config.age.secrets.vaultwarden-env.path;
  };

  # Replace uses of old name
  systemd.services.backup-vaultwarden.environment.DATA_FOLDER = lib.mkForce "/var/lib/vaultwarden";
  systemd.services.vaultwarden.serviceConfig = {
    StateDirectory = lib.mkForce "vaultwarden";
    RestartSec = "600"; # Retry every 10 minutes
  };
}
