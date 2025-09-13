{
  config,
  globals,
  lib,
  ...
}:
let
  vaultwardenDomain = "pw.${globals.domains.personal}";
in
{
  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [ config.services.vaultwarden.config.rocketPort ];
  };

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

  globals.services.vaultwarden.domain = vaultwardenDomain;
  globals.monitoring.http.vaultwarden = {
    url = "https://${vaultwardenDomain}";
    expectedBodyRegex = "Vaultwarden Web";
    network = "internet";
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams.vaultwarden = {
        servers."${
          globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
        }:${toString config.services.vaultwarden.config.rocketPort}" =
          { };
        extraConfig = ''
          zone vaultwarden 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "Vaultwarden Web";
        };
      };
      virtualHosts.${vaultwardenDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        extraConfig = ''
          client_max_body_size 256M;
        '';
        locations."/" = {
          proxyPass = "http://vaultwarden";
          proxyWebsockets = true;
          X-Frame-Options = "SAMEORIGIN";
        };
      };
    };
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    # WARN: Careful! The backup script does not remove files in the backup location
    # if they were removed in the original location! Therefore, we use a directory
    # that is not persisted and thus clean on every reboot.
    backupDir = "/var/cache/vaultwarden-backup";
    config = {
      dataFolder = lib.mkForce "/var/lib/vaultwarden";
      extendedLogging = true;
      useSyslog = true;
      webVaultEnabled = true;

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
    environmentFile = config.age.secrets.vaultwarden-env.path;
  };

  # Replace uses of old name
  systemd.services.backup-vaultwarden.environment.DATA_FOLDER = lib.mkForce "/var/lib/vaultwarden";
  systemd.services.vaultwarden.serviceConfig = {
    StateDirectory = lib.mkForce "vaultwarden";
    RestartSec = "60"; # Retry every minute
  };

  # Needed so we don't run out of tmpfs space for large backups.
  # Technically this could be cleared each boot but whatever.
  environment.persistence."/state".directories = [
    {
      directory = config.services.vaultwarden.backupDir;
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "0700";
    }
  ];

  backups.storageBoxes.dusk = {
    subuser = "vaultwarden";
    paths = [ config.services.vaultwarden.backupDir ];
  };
}
