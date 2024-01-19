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
      virtualHosts.${vaultwardenDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        extraConfig = ''
          client_max_body_size 256M;
        '';
        locations."/".proxyPass = "http://vaultwarden";
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
    #backupDir = "/data/backup";
    environmentFile = config.age.secrets.vaultwarden-env.path;
  };

  # Replace uses of old name
  systemd.services.backup-vaultwarden.environment.DATA_FOLDER = lib.mkForce "/var/lib/vaultwarden";
  systemd.services.vaultwarden.serviceConfig = {
    StateDirectory = lib.mkForce "vaultwarden";
    RestartSec = "600"; # Retry every 10 minutes
  };

  # Backups
  # ========================================================================

  age.secrets.restic-encryption-password.generator.script = "alnum";
  age.secrets.restic-ssh-privkey.generator.script = "ssh-ed25519";

  services.restic.backups.main = {
    hetznerStorageBox = let
      box = config.repo.secrets.global.hetzner.storageboxes.dusk;
    in {
      enable = true;
      inherit (box) mainUser;
      inherit (box.users.vaultwarden) subUid path;
      sshAgeSecret = "restic-ssh-privkey";
    };

    user = "vaultwarden";
    timerConfig = {
      OnCalendar = "06:15";
      RandomizedDelaySec = "3h";
      Persistent = true;
    };
    initialize = true;
    passwordFile = config.age.secrets.restic-encryption-password.path;
    paths = [config.services.vaultwarden.backupDir];
    pruneOpts = [
      "--keep-daily 14"
      "--keep-weekly 7"
      "--keep-monthly 12"
      "--keep-yearly 75"
    ];
  };
}
