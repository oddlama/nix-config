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
  imports = [
    ../../../../modules/proxy-via-sentinel.nix
  ];

  age.secrets.vaultwarden-env = {
    rekeyFile = ./secrets/vaultwarden-env.age;
    mode = "440";
    group = "vaultwarden";
  };

  networking.nftables.firewall.rules = lib.mkForce {
    sentinel-to-local.allowedTCPPorts = [
      config.services.vaultwarden.config.rocketPort
      config.services.vaultwarden.config.websocketPort
    ];
  };

  nodes.sentinel = {
    proxiedDomains.vaultwarden = vaultwardenDomain;

    services.caddy.virtualHosts.${vaultwardenDomain} = {
      useACMEHost = sentinelCfg.lib.extra.matchingWildcardCert vaultwardenDomain;
      extraConfig = ''
        import common

        reverse_proxy {
          to http://${config.services.vaultwarden.config.rocketAddress}:${toString config.services.vaultwarden.config.rocketPort}
          header_up X-Real-IP {remote_host}
        }

        reverse_proxy /notifications/hub {
          to http://${config.services.vaultwarden.config.websocketAddress}:${toString config.services.vaultwarden.config.websocketPort}
          header_up X-Real-IP {remote_host}
        }

        reverse_proxy /notifications/hub/negotiate {
          to http://${config.services.vaultwarden.config.rocketAddress}:${toString config.services.vaultwarden.config.rocketPort}
          header_up X-Real-IP {remote_host}
        }
      '';
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
      websocketAddress = config.extra.wireguard.proxy-sentinel.ipv4;
      websocketPort = 3012;
      rocketAddress = config.extra.wireguard.proxy-sentinel.ipv4;
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
  };
}
