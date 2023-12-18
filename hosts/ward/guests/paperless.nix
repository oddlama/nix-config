{
  config,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  paperlessDomain = "paperless.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  # XXX: remove microvm.mem = 1024 * 12;
  # XXX: remove microvm.vcpu = 4;

  meta.wireguard-proxy.sentinel.allowedTCPPorts = [
    config.services.paperless.port
  ];

  age.secrets.paperless-admin-password = {
    rekeyFile = config.node.secretsDir + "/paperless-admin-password.age";
    generator.script = "alnum";
    mode = "440";
    group = "paperless";
  };

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

  # TODO environment.persistence."/persist".directories = [
  # TODO   {
  # TODO     directory = "/var/lib/???";
  # TODO     user = "???";
  # TODO     group = "???";
  # TODO     mode = "0700";
  # TODO   }
  # TODO ];

  services.paperless = {
    enable = true;
    address = "0.0.0.0";
    passwordFile = config.age.secrets.paperless-admin-password.path;
    extraConfig = {
      PAPERLESS_URL = "https://${paperlessDomain}";
      PAPERLESS_CONSUMER_ENABLE_BARCODES = true;
      PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE = true;
      PAPERLESS_CONSUMER_BARCODE_SCANNER = "ZXING";
      PAPERLESS_FILENAME_FORMAT = "{created_year}-{created_month}-{created_day}_{asn}_{title}";
      #PAPERLESS_IGNORE_DATES = concatStringsSep "," ignoreDates;
      PAPERLESS_NUMBER_OF_SUGGESTED_DATES = 4;
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_TASK_WORKERS = 4;
      PAPERLESS_WEBSERVER_WORKERS = 4;
    };
  };

  systemd.services.paperless.serviceConfig.RestartSec = "600"; # Retry every 10 minutes
}
