{
  config,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  radicaleDomain = "radicale.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [
    8000
  ];

  nodes.sentinel = {
    networking.providedDomains.radicale = radicaleDomain;

    services.nginx = {
      upstreams.radicale = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:8000" = {};
        extraConfig = ''
          zone radicale 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${radicaleDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        extraConfig = ''
          client_max_body_size 16M;
        '';
        locations."/".proxyPass = "http://radicale";
      };
    };
  };

  age.secrets.radicale-users = {
    rekeyFile = config.node.secretsDir + "/radicale-users.age";
    mode = "440";
    group = "radicale";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/radicale";
      user = "radicale";
      group = "radicale";
      mode = "0700";
    }
  ];

  services.radicale = {
    enable = true;
    settings = {
      server = {
        hosts = ["0.0.0.0:8000" "[::]:8000"];
      };
      auth = {
        type = "htpasswd";
        htpasswd_filename = config.age.secrets.radicale-users.path;
        htpasswd_encryption = "bcrypt";
      };
      storage = {
        filesystem_folder = "/var/lib/radicale/collections";
      };
    };
    rights = {
      root = {
        user = ".+";
        collection = "";
        permissions = "R";
      };
      principal = {
        user = ".+";
        collection = "{user}";
        permissions = "RW";
      };
      calendars = {
        user = ".+";
        collection = "{user}/[^/]+";
        permissions = "rw";
      };
    };
  };

  systemd.services.radicale.serviceConfig.RestartSec = "600"; # Retry every 10 minutes

  backups.storageBoxes.dusk = {
    subuser = "radicale";
    paths = ["/var/lib/radicale"];
  };
}
