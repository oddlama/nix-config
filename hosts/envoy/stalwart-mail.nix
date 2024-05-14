{
  config,
  lib,
  ...
}: let
  mailDomains = config.repo.secrets.global.domains.mail;
  primaryDomain = mailDomains.primary;
in {
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/stalwart-mail";
      owner = "stalwart-mail";
      group = "stalwart-mail";
      mode = "0700";
    }
  ];

  users.groups.acme.members = ["stalwart-mail"];
  users.groups.stalwart-mail = {};
  users.users.stalwart-mail = {
    isSystemUser = true;
    home = "/var/lib/stalwart-mail";
    group = "stalwart-mail";
  };

  networking.firewall.allowedTCPPorts = [
    25 # smtp
    465 # submission tls
    # 587 # submission starttls
    993 # imap tls
    # 143 # imap starttls
    8080 # stalwart-mail http
    4190 # manage sieve
  ];

  systemd.services.stalwart-mail = {
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      StandardOutput = lib.mkForce "journal";
      StandardError = lib.mkForce "journal";
      SupplementaryGroups = ["acme"];
    };
  };

  services.stalwart-mail = {
    enable = true;

    settings = {
      #include.files = [secrets."stalwart.toml".path];
      #config.local-keys = [
      #  "store.*"
      #  "directory.*"
      #  "tracer.*"
      #  "server.*"
      #  "!server.blocked-ip.*"
      #  "authentication.fallback-admin.*"
      #  "cluster.node-id"
      #  "storage.data"
      #  "storage.blob"
      #  "storage.lookup"
      #  "storage.fts"
      #  "storage.directory"
      #  "lookup.default.hostname"
      #  "certificate.*"
      #];

      global.tracing.level = "trace";
      resolver.public-suffix = [
        "https://publicsuffix.org/list/public_suffix_list.dat"
      ];

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
          jmap = {
            protocol = "jmap";
            bind = " [::]:18080";
            url = "https://mail.${primaryDomain}/jmap";
          };
          imaps = {
            protocol = "imap";
            bind = "[::]:1993";
            tls.enable = true;
            tls.implicit = true;
          };
        };
      };

      session = {
        rcpt = {
          directory = "default";
          relay = [
            {
              "if" = "authenticated-as";
              ne = "";
              "then" = true;
            }
            {"else" = false;}
          ];
        };
      };

      queue = {
        outbound = {
          next-hop = [
            {
              "if" = "rcpt-domain";
              in-list = "default/domains";
              "then" = "local";
            }
            {"else" = "relay";}
          ];
          tls = {
            mta-sts = "disable";
            dane = "disable";
          };
        };
      };

      remote.relay = {
        protocol = "smtp";
        address = "127.0.0.1";
        port = 25;
      };

      jmap = {
        directory = "default";
        http.headers = [
          "Access-Control-Allow-Origin: *"
          "Access-Control-Allow-Methods: POST, GET, HEAD, OPTIONS"
          "Access-Control-Allow-Headers: *"
        ];
      };

      management.directory = "default";

      certificate.default = {
        cert = "file://${cfg.certFile}";
        private-key = "file://${cfg.keyFile}";
      };
    };
  };
}
