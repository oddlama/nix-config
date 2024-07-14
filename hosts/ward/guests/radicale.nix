{config, ...}: let
  radicaleDomain = "radicale.${config.repo.secrets.global.domains.personal}";
in {
  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [8000];
  };

  globals.services.radicale.domain = radicaleDomain;
  globals.monitoring.http.radicale = {
    url = "https://${radicaleDomain}";
    location = "home";
    network = "internet";
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams.radicale = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:8000" = {};
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

  topology.self.services.radicale.info = "https://" + radicaleDomain;
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

  systemd.services.radicale.serviceConfig.RestartSec = "60"; # Retry every minute

  backups.storageBoxes.dusk = {
    subuser = "radicale";
    paths = ["/var/lib/radicale"];
  };
}
