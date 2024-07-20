{
  config,
  lib,
  pkgs,
  ...
}: let
  mailDomains = config.repo.secrets.global.domains.mail;
  primaryDomain = mailDomains.primary;
  stalwartDomain = "mail.${primaryDomain}";
  dataDir = "/var/lib/stalwart-mail";
in {
  environment.persistence."/persist".directories = [
    {
      directory = dataDir;
      user = "stalwart-mail";
      group = "stalwart-mail";
      mode = "0700";
    }
  ];

  users.groups.acme.members = ["stalwart-mail"];

  networking.firewall.allowedTCPPorts = [
    25 # smtp
    465 # submission tls
    # 587 # submission starttls
    993 # imap tls
    # 143 # imap starttls
    4190 # manage sieve
  ];

  globals.services.stalwart.domain = stalwartDomain;
  globals.monitoring.http.stalwart = {
    url = "https://${stalwartDomain}";
    expectedBodyRegex = "Stalwart Management";
    network = "internet";
  };

  services.stalwart-mail = {
    enable = true;

    settings = lib.mkForce {
      authentication.fallback-admin = {
        user = "admin";
        secret = "$6$tOo2HQnlyAcgyfx5$aMI3uELtqsjkN.gHn8f2W2yxl2ovo.6PU9XxT9jvjJ2CNXpwpumlBq.ZaERPQcTzl4.o1vklB.sdBevXBrLPp0";
      };

      tracer.stdout = {
        # Do not use the built-in journal tracer, as it shows much less auxiliary
        # information for the same loglevel
        type = "stdout";
        level = "info";
        ansi = false; # no colour markers to journald
        enable = true;
      };

      store.db = {
        type = "sqlite";
        path = "${dataDir}/database.sqlite3";
      };

      storage = {
        data = "db";
        fts = "db";
        lookup = "db";
        blob = "db";
        directory = "internal";
      };

      directory.internal = {
        type = "internal";
        store = "db";
      };

      resolver = {
        type = "system";
        public-suffix = [
          "file://${pkgs.publicsuffix-list}/share/publicsuffix/public_suffix_list.dat"
        ];
      };

      config.resource.spam-filter = "file://${config.services.stalwart-mail.package}/etc/stalwart/spamfilter.toml";

      certificate.default = {
        cert = "%{file:${config.security.acme.certs.${primaryDomain}.directory}/fullchain.pem}%";
        private-key = "%{file:${config.security.acme.certs.${primaryDomain}.directory}/key.pem}%";
        default = true;
      };

      server = {
        hostname = "mx1.${primaryDomain}";
        tls = {
          certificate = "default";
          ignore-client-order = true;
        };
        socket = {
          nodelay = true;
          reuse-addr = true;
        };
        listener = {
          smtp = {
            protocol = "smtp";
            bind = "[::]:25";
          };
          submissions = {
            protocol = "smtp";
            bind = "[::]:465";
            tls.implicit = true;
          };
          imaps = {
            protocol = "imap";
            bind = "[::]:993";
            tls.implicit = true;
          };
          http = {
            # jmap, web interface
            protocol = "http";
            bind = "[::]:8080";
            url = "https://${stalwartDomain}/jmap";
          };
          sieve = {
            protocol = "managesieve";
            bind = "[::]:4190";
            tls.implicit = true;
          };
        };
      };
    };
  };

  services.nginx = {
    upstreams.stalwart = {
      servers."localhost:8080" = {};
      extraConfig = ''
        zone stalwart 64k;
        keepalive 2;
      '';
    };
    virtualHosts.${stalwartDomain} = {
      forceSSL = true;
      useACMEWildcardHost = true;
      extraConfig = ''
        client_max_body_size 512M;
      '';
      locations."/" = {
        proxyPass = "http://stalwart";
        proxyWebsockets = true;
      };
    };
  };

  systemd.services.stalwart-mail = let
    cfg = config.services.stalwart-mail;
    configFormat = pkgs.formats.toml {};
    configFile = configFormat.generate "stalwart-mail.toml" cfg.settings;
  in {
    preStart = lib.mkAfter ''
      cat ${configFile} > /run/stalwart-mail/config.toml
    '';
    serviceConfig = {
      RuntimeDirectory = "stalwart-mail";
      ExecStart = lib.mkForce [
        ""
        "${cfg.package}/bin/stalwart-mail --config=/run/stalwart-mail/config.toml"
      ];
      RestartSec = "60"; # Retry every minute
    };
  };
}
