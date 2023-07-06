{
  config,
  lib,
  nodes,
  utils,
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

  nodes.sentinel = {
    networking.providedDomains.vaultwarden = vaultwardenDomain;

    services.nginx = {
      upstreams.vaultwarden = {
        servers."${config.services.vaultwarden.config.rocketAddress}:${toString config.services.vaultwarden.config.rocketPort}" = {};
        extraConfig = ''
          zone vaultwarden 64k;
          keepalive 2;
        '';
      };
      upstreams.vaultwarden-websocket = {
        servers."${config.services.vaultwarden.config.websocketAddress}:${toString config.services.vaultwarden.config.websocketPort}" = {};
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
      websocketAddress = config.meta.wireguard.proxy-sentinel.ipv4;
      websocketPort = 3012;
      rocketAddress = config.meta.wireguard.proxy-sentinel.ipv4;
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
  systemd.services.vaultwarden = {
    after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "proxy-sentinel"}.device"];
    serviceConfig.StateDirectory = lib.mkForce "vaultwarden";
    serviceConfig.RestartSec = "600"; # Retry every 10 minutes
  };
}
