{
  config,
  globals,
  lib,
  pkgs,
  ...
}: let
  primaryDomain = globals.mail.primary;
  stalwartDomain = "mail.${primaryDomain}";
  dataDir = "/var/lib/stalwart-mail";
  mailBackupDir = "/var/cache/mail-backup";
in {
  environment.persistence."/persist".directories = [
    {
      directory = dataDir;
      user = "stalwart-mail";
      group = "stalwart-mail";
      mode = "0700";
    }
  ];

  age.secrets.stalwart-admin-pw = {
    generator.script = "alnum";
    mode = "000";
  };

  age.secrets.stalwart-admin-hash = {
    generator.dependencies = [config.age.secrets.stalwart-admin-pw];
    generator.script = "argon2id";
    mode = "440";
    group = "stalwart-mail";
  };

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
    settings = let
      case = field: check: value: data: {
        "if" = field;
        ${check} = value;
        "then" = data;
      };
      ifthen = field: data: {
        "if" = field;
        "then" = data;
      };
      otherwise = value: {"else" = value;};
      is-smtp = case "listener" "eq" "smtp";
      is-authenticated = data: {
        "if" = "!is_empty(authenticated_as)";
        "then" = data;
      };
    in
      lib.mkForce {
        config.local-keys = [
          "store.*"
          "directory.*"
          "tracer.*"
          "server.*"
          "!server.blocked-ip.*"
          "!server.allowed-ip.*"
          "authentication.fallback-admin.*"
          "cluster.node-id"
          "storage.data"
          "storage.blob"
          "storage.lookup"
          "storage.fts"
          "storage.directory"
          "lookup.default.hostname"
          "certificate.*"
          "auth.dkim.*"
          "signature.*"
        ];

        authentication.fallback-admin = {
          user = "admin";
          secret = "%{file:/run/stalwart-mail/admin-hash}%";
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

        store.idmail = {
          type = "sqlite";
          path = "${config.services.idmail.dataDir}/idmail.db";
          query = let
            # Remove comments from SQL and make it single-line
            toSingleLineSql = sql:
              lib.concatStringsSep " " (
                lib.forEach (lib.flatten (lib.split "\n" sql)) (
                  line: lib.optionalString (builtins.match "^[[:space:]]*--.*" line == null) line
                )
              );
          in {
            # "SELECT name, type, secret, description, quota FROM accounts WHERE name = ?1 AND active = true";
            name = toSingleLineSql ''
              SELECT
                  m.address AS name,
                  'individual' AS type,
                  m.password_hash AS secret,
                  m.address AS description,
                  0 AS quota
                FROM mailboxes AS m
                JOIN domains AS d ON m.domain = d.domain
                JOIN users AS u ON m.owner = u.username
                WHERE m.address = ?1
                  AND m.active = true
                  AND d.active = true
                  AND u.active = true
            '';
            # "SELECT member_of FROM group_members WHERE name = ?1";
            members = "";
            # "SELECT name FROM emails WHERE address = ?1";
            recipients = toSingleLineSql ''
              -- It is important that we return only one value here, but in theory three UNIONed
              -- queries are guaranteed to be distinct. This is because a mailbox address
              -- and alias address can never be the same, their cross-table uniqueness is guaranteed on insert.
              -- The catch-all union can also only return something if @domain.tld is given as a parameter,
              -- which is invalid for aliases and mailboxes.
              --
              -- Nonetheless, it may be beneficial to allow an alias to override an existing mailbox,
              -- so we can have send-only mailboxes which have their incoming mail redirected somewhere else.
              -- Therefore, we make sure to order the query by (aliases -> mailboxes -> catch all) and only return the
              -- highest priority one.
              SELECT name FROM (
                -- Select the target of a matching alias (if any)
                -- but make sure that all related parts are active.
                SELECT a.target AS name, 1 AS rowOrder
                  FROM aliases AS a
                  JOIN domains AS d ON a.domain = d.domain
                  JOIN (
                    -- To check whether the owner is active we need to make a subquery
                    -- because the owner could be a user or mailbox
                    SELECT username
                      FROM users
                      WHERE active = true
                    UNION
                    SELECT m.address AS username
                      FROM mailboxes AS m
                      JOIN users AS u ON m.owner = u.username
                      WHERE m.active = true
                        AND u.active = true
                  ) AS u ON a.owner = u.username
                  WHERE a.address = ?1
                    AND a.active = true
                    AND d.active = true
                -- Select the primary mailbox address if it matches and
                -- all related parts are active.
                UNION
                SELECT m.address AS name, 2 AS rowOrder
                  FROM mailboxes AS m
                  JOIN domains AS d ON m.domain = d.domain
                  JOIN users AS u ON m.owner = u.username
                  WHERE m.address = ?1
                    AND m.active = true
                    AND d.active = true
                    AND u.active = true
                -- Finally, select any catch_all address that would catch this.
                -- Again make sure everything is active.
                UNION
                SELECT d.catch_all AS name, 3 AS rowOrder
                  FROM domains AS d
                  JOIN mailboxes AS m ON d.catch_all = m.address
                  JOIN users AS u ON m.owner = u.username
                  WHERE ?1 = ('@' || d.domain)
                    AND d.active = true
                    AND m.active = true
                    AND u.active = true
                ORDER BY rowOrder, name ASC
                LIMIT 1
              )
            '';
            # "SELECT address FROM emails WHERE name = ?1 AND type != 'list' ORDER BY type DESC, address ASC";
            emails = toSingleLineSql ''
              -- Return first the primary address, then any aliases.
              SELECT address FROM (
                -- Select primary address, if active
                SELECT m.address AS address, 1 AS rowOrder
                  FROM mailboxes AS m
                  JOIN domains AS d ON m.domain = d.domain
                  JOIN users AS u ON m.owner = u.username
                  WHERE m.address = ?1
                    AND m.active = true
                    AND d.active = true
                    AND u.active = true
                -- Select any active aliases
                UNION
                SELECT a.address AS address, 2 AS rowOrder
                  FROM aliases AS a
                  JOIN domains AS d ON a.domain = d.domain
                  JOIN (
                    -- To check whether the owner is active we need to make a subquery
                    -- because the owner could be a user or mailbox
                    SELECT username
                      FROM users
                      WHERE active = true
                    UNION
                    SELECT m.address AS username
                      FROM mailboxes AS m
                      JOIN users AS u ON m.owner = u.username
                      WHERE m.active = true
                        AND u.active = true
                  ) AS u ON a.owner = u.username
                  WHERE a.target = ?1
                    AND a.active = true
                    AND d.active = true
                -- Select the catch-all marker, if we are the target.
                UNION
                -- Order 2 is correct, it counts as an alias
                SELECT ('@' || d.domain) AS address, 2 AS rowOrder
                  FROM domains AS d
                  JOIN mailboxes AS m ON d.catch_all = m.address
                  JOIN users AS u ON m.owner = u.username
                  WHERE d.catch_all = ?1
                    AND d.active = true
                    AND m.active = true
                    AND u.active = true
                ORDER BY rowOrder, address ASC
              )
            '';
            # "SELECT address FROM emails WHERE address LIKE '%' || ?1 || '%' AND type = 'primary' ORDER BY address LIMIT 5";
            verify = toSingleLineSql ''
              SELECT m.address AS address
                FROM mailboxes AS m
                JOIN domains AS d ON m.domain = d.domain
                JOIN users AS u ON m.owner = u.username
                WHERE m.address LIKE '%' || ?1 || '%'
                  AND m.active = true
                  AND d.active = true
                  AND u.active = true
              UNION
              SELECT a.address AS address
                FROM aliases AS a
                JOIN domains AS d ON a.domain = d.domain
                JOIN (
                  -- To check whether the owner is active we need to make a subquery
                  -- because the owner could be a user or mailbox
                  SELECT username
                    FROM users
                    WHERE active = true
                  UNION
                  SELECT m.address AS username
                    FROM mailboxes AS m
                    JOIN users AS u ON m.owner = u.username
                    WHERE m.active = true
                      AND u.active = true
                ) AS u ON a.owner = u.username
                WHERE a.address LIKE '%' || ?1 || '%'
                  AND a.active = true
                  AND d.active = true
              ORDER BY address
              LIMIT 5
            '';
            # "SELECT p.address FROM emails AS p JOIN emails AS l ON p.name = l.name WHERE p.type = 'primary' AND l.address = ?1 AND l.type = 'list' ORDER BY p.address LIMIT 50";
            # XXX: We don't actually expand, but return the same address if it exists since we don't support mailing lists
            expand = toSingleLineSql ''
              SELECT m.address AS address
                FROM mailboxes AS m
                JOIN domains AS d ON m.domain = d.domain
                JOIN users AS u ON m.owner = u.username
                WHERE m.address = ?1
                  AND m.active = true
                  AND d.active = true
                  AND u.active = true
              UNION
              SELECT a.address AS address
                FROM aliases AS a
                JOIN domains AS d ON a.domain = d.domain
                JOIN (
                  -- To check whether the owner is active we need to make a subquery
                  -- because the owner could be a user or mailbox
                  SELECT username
                    FROM users
                    WHERE active = true
                  UNION
                  SELECT m.address AS username
                    FROM mailboxes AS m
                    JOIN users AS u ON m.owner = u.username
                    WHERE m.active = true
                      AND u.active = true
                ) AS u ON a.owner = u.username
                WHERE a.address = ?1
                  AND a.active = true
                  AND d.active = true
              ORDER BY address
              LIMIT 50
            '';
            # "SELECT 1 FROM emails WHERE address LIKE '%@' || ?1 LIMIT 1";
            domains = toSingleLineSql ''
              SELECT domain
                FROM domains
                WHERE domain = ?1
            '';
          };
        };

        storage = {
          data = "db";
          fts = "db";
          lookup = "db";
          blob = "db";
          directory = "idmail";
        };

        directory.idmail = {
          type = "sql";
          store = "idmail";
          columns = {
            name = "name";
            description = "description";
            secret = "secret";
            email = "email";
            #quota = "quota";
            class = "type";
          };
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

        lookup.default.hostname = stalwartDomain;
        server = {
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
              url = "https://${stalwartDomain}";
              use-x-forwarded = true;
            };
            sieve = {
              protocol = "managesieve";
              bind = "[::]:4190";
              tls.implicit = true;
            };
          };
        };

        imap = {
          request.max-size = 52428800;
          auth = {
            max-failures = 3;
            allow-plain-text = false;
          };
          timeout = {
            authentication = "30m";
            anonymous = "1m";
            idle = "30m";
          };
          rate-limit = {
            requests = "20000/1m";
            concurrent = 32;
          };
        };

        auth.dkim.sign = [
          (ifthen "is_local_domain('*', sender_domain)" "['rsa-' + sender_domain, 'ed25519-' + sender_domain]")
          (otherwise false)
        ];

        signature = lib.mergeAttrsList (
          lib.forEach (builtins.attrNames globals.mail.domains) (domain: {
            "ed25519-${domain}" = {
              private-key = "%{file:/var/lib/stalwart-mail/dkim/ed25519-${domain}.key}%";
              inherit domain;
              selector = "ed_default";
              headers = ["From" "To" "Date" "Subject" "Message-ID"];
              algorithm = "ed25519-sha256";
              canonicalization = "relaxed/relaxed";
              set-body-length = false;
              report = true;
            };
            "rsa-${domain}" = {
              private-key = "%{file:/var/lib/stalwart-mail/dkim/rsa-${domain}.key}%";
              inherit domain;
              selector = "rsa_default";
              headers = ["From" "To" "Date" "Subject" "Message-ID"];
              algorithm = "rsa-sha256";
              canonicalization = "relaxed/relaxed";
              set-body-length = false;
              report = true;
            };
          })
        );

        session.extensions = {
          pipelining = true;
          chunking = true;
          requiretls = true;
          no-soliciting = "";
          dsn = false;
          expn = [
            (is-authenticated true)
            (otherwise false)
          ];
          vrfy = [
            (is-authenticated true)
            (otherwise false)
          ];
          future-release = [
            (is-authenticated "30d")
            (otherwise false)
          ];
          deliver-by = [
            (is-authenticated "365d")
            (otherwise false)
          ];
          mt-priority = [
            (is-authenticated "mixer")
            (otherwise false)
          ];
        };

        session.ehlo = {
          require = true;
          reject-non-fqdn = [
            (is-smtp true)
            (otherwise false)
          ];
        };

        session.rcpt = {
          catch-all = true;
          relay = [
            (is-authenticated true)
            (otherwise false)
          ];
          max-recipients = 25;
        };
      };
  };

  services.nginx = {
    upstreams.stalwart = {
      servers."127.0.0.1:8080" = {};
      extraConfig = ''
        zone stalwart 64k;
        keepalive 2;
      '';
    };
    virtualHosts =
      {
        ${stalwartDomain} = {
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
      }
      // lib.genAttrs ["autoconfig.${primaryDomain}" "autodiscover.${primaryDomain}" "mta-sts.${primaryDomain}"] (_: {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/".proxyPass = "http://stalwart";
      });
  };

  systemd.services.stalwart-mail = let
    cfg = config.services.stalwart-mail;
    configFormat = pkgs.formats.toml {};
    configFile = configFormat.generate "stalwart-mail.toml" cfg.settings;
  in {
    preStart = lib.mkAfter (
      ''
        cat ${configFile} > /run/stalwart-mail/config.toml
        cat ${config.age.secrets.stalwart-admin-hash.path} \
          | tr -d '\n' > /run/stalwart-mail/admin-hash

        mkdir -p /var/lib/stalwart-mail/dkim
      ''
      # Generate DKIM keys if necessary
      + lib.concatLines (
        lib.forEach (builtins.attrNames globals.mail.domains) (domain: ''
          if [[ ! -e /var/lib/stalwart-mail/dkim/rsa-${domain}.key ]]; then
            echo "Generating DKIM key for ${domain} (rsa)"
            ${lib.getExe pkgs.openssl} genrsa -traditional -out /var/lib/stalwart-mail/dkim/rsa-${domain}.key 2048
          fi
          if [[ ! -e /var/lib/stalwart-mail/dkim/ed25519-${domain}.key ]]; then
            echo "Generating DKIM key for ${domain} (ed25519)"
            ${lib.getExe pkgs.openssl} genpkey -algorithm ed25519 -out /var/lib/stalwart-mail/dkim/ed25519-${domain}.key
          fi
        '')
      )
    );

    serviceConfig = {
      RuntimeDirectory = "stalwart-mail";
      ReadWritePaths = [config.services.idmail.dataDir];
      ExecStart = lib.mkForce [
        ""
        "${cfg.package}/bin/stalwart-mail --config=/run/stalwart-mail/config.toml"
      ];
      RestartSec = "60"; # Retry every minute
    };
  };

  systemd.services.backup-mail = {
    description = "Mail backup";
    environment = {
      STALWART_DATA = dataDir;
      IDMAIL_DATA = config.services.idmail.dataDir;
      BACKUP_DIR = mailBackupDir;
    };
    serviceConfig = {
      SyslogIdentifier = "backup-mail";
      Type = "oneshot";
      User = "stalwart-mail";
      Group = "stalwart-mail";
      ExecStart = lib.getExe (pkgs.writeShellApplication {
        name = "backup-mail";
        runtimeInputs = [pkgs.sqlite];
        text = ''
          sqlite3 "$STALWART_DATA/database.sqlite3" ".backup '$BACKUP_DIR/database.sqlite3'"
          sqlite3 "$IDMAIL_DATA/database.sqlite3" ".backup '$BACKUP_DIR/idmail.db'"
          cp -r "$STALWART_DATA/dkim" "$BACKUP_DIR/"
        '';
      });
      ReadWritePaths = [
        dataDir
        config.services.idmail.dataDir
        mailBackupDir
      ];
      Restart = "no";
    };
    requiredBy = ["restic-backups-storage-box-dusk.service"];
    before = ["restic-backups-storage-box-dusk.service"];
  };

  # Needed so we don't run out of tmpfs space for large backups.
  # Technically this could be cleared each boot but whatever.
  environment.persistence."/state".directories = [
    {
      directory = mailBackupDir;
      user = "stalwart-mail";
      group = "stalwart-mail";
      mode = "0700";
    }
  ];

  backups.storageBoxes.dusk = {
    subuser = "stalwart";
    paths = [mailBackupDir];
  };
}
