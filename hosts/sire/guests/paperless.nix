{
  config,
  lib,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  paperlessDomain = "paperless.${config.repo.secrets.global.domains.me}";
  paperlessBackupDir = "/var/cache/paperless-backup";
in {
  microvm.mem = 1024 * 9;
  microvm.vcpu = 8;

  nodes.sentinel = {
    networking.providedDomains.paperless = paperlessDomain;

    services.nginx = {
      upstreams.paperless = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:${toString config.services.paperless.port}" = {};
        extraConfig = ''
          zone paperless 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${paperlessDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        extraConfig = ''
          client_max_body_size 512M;
        '';
        locations."/" = {
          proxyPass = "http://paperless";
          proxyWebsockets = true;
          X-Frame-Options = "SAMEORIGIN";
        };
      };
    };
  };

  meta.wireguard-proxy.sentinel.allowedTCPPorts = [
    config.services.paperless.port
  ];

  age.secrets.paperless-admin-password = {
    generator.script = "alnum";
    mode = "440";
    group = "paperless";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/paperless";
      user = "paperless";
      group = "paperless";
      mode = "0750";
    }
  ];

  # TODO: workaround for https://github.com/paperless-ngx/paperless-ngx/discussions/5606
  systemd.services.paperless-web.script = lib.mkBefore ''
    mkdir -p /tmp/paperless
  '';

  services.paperless = {
    enable = true;
    address = "0.0.0.0";
    passwordFile = config.age.secrets.paperless-admin-password.path;
    consumptionDir = "/paperless/consume";
    mediaDir = "/paperless/media";
    settings = {
      PAPERLESS_URL = "https://${paperlessDomain}";
      PAPERLESS_ALLOWED_HOSTS = paperlessDomain;
      PAPERLESS_CORS_ALLOWED_HOSTS = "https://${paperlessDomain}";
      PAPERLESS_TRUSTED_PROXIES = sentinelCfg.meta.wireguard.proxy-sentinel.ipv4;

      # Ghostscript is entirely bug-free.
      PAPERLESS_OCR_USER_ARGS = builtins.toJSON {
        continue_on_soft_render_error = true;
      };

      # virtiofsd doesn't send inotify events (not sure if generally, or because we
      # mount the same host share on another vm (samba) and modify it there).
      PAPERLESS_CONSUMER_POLLING = 1; # seconds
      # Wait three seconds between file-modified checks. After 5 consecutive checks
      # where the file wasn't modified it will be consumed.
      PAPERLESS_CONSUMER_POLLING_DELAY = 3;

      PAPERLESS_CONSUMER_ENABLE_BARCODES = true;
      PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE = true;
      PAPERLESS_CONSUMER_BARCODE_SCANNER = "ZXING";
      PAPERLESS_CONSUMER_RECURSIVE = true;
      PAPERLESS_FILENAME_FORMAT = "{owner_username}/{created_year}-{created_month}-{created_day}_{asn}_{title}";

      # Nginx does that better.
      PAPERLESS_ENABLE_COMPRESSION = false;

      #PAPERLESS_IGNORE_DATES = concatStringsSep "," ignoreDates;
      PAPERLESS_NUMBER_OF_SUGGESTED_DATES = 8;
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_TASK_WORKERS = 4;
      PAPERLESS_WEBSERVER_WORKERS = 4;
    };
  };

  systemd.services.paperless.serviceConfig.RestartSec = "60"; # Retry every minute

  systemd.tmpfiles.settings."10-paperless".${paperlessBackupDir}.d = {
    inherit (config.services.paperless) user;
    mode = "0700";
  };

  systemd.services.paperless-backup = let
    cfg = config.systemd.services.paperless-consumer;
  in {
    description = "Paperless documents backup";
    serviceConfig = lib.recursiveUpdate cfg.serviceConfig {
      ExecStart = "${config.services.paperless.package}/bin/paperless-ngx document_exporter -na -nt -f -d ${paperlessBackupDir}";
      ReadWritePaths = cfg.serviceConfig.ReadWritePaths ++ [paperlessBackupDir];
      Restart = "no";
      Type = "oneshot";
    };
    inherit (cfg) environment;
    requiredBy = ["restic-backups-storage-box-dusk.service"];
    before = ["restic-backups-storage-box-dusk.service"];
  };

  # Needed so we don't run out of tmpfs space for large backups.
  # Technically this could be cleared each boot but whatever.
  environment.persistence."/state".directories = [
    {
      directory = paperlessBackupDir;
      user = "paperless";
      group = "paperless";
      mode = "0700";
    }
  ];

  backups.storageBoxes.dusk = {
    subuser = "paperless";
    paths = [paperlessBackupDir];
  };
}
