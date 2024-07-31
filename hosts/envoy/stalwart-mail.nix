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

  age.secrets.stalwart-admin-hash = {
    rekeyFile = ./secrets/stalwart-admin-hash.age;
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
      otherwise = value: {"else" = value;};
      is-smtp = case "listener" "eq" "smtp";
      is-authenticated = data: {
        "if" = "!is_empty(authenticated_as)";
        "then" = data;
      };
    in
      lib.mkForce {
        authentication.fallback-admin = {
          user = "admin";
          secret = "%{file:${config.age.secrets.stalwart-admin-hash.path}}%";
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
          path = "${dataDir}/idmail.db";
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
              -- It is important that we return only one value here, but these three UNIONed
              -- queries are guaranteed to be distinct. This is because a mailbox address
              -- and alias address can never be the same, their cross-table uniqueness is guaranteed on insert.
              -- The catch-all union can also only return something if @domain.tld is given as a parameter,
              -- which is invalid for aliases and mailboxes.

              -- Select the primary mailbox address if it matches and
              -- all related parts are active
              SELECT m.address AS name
                FROM mailboxes AS m
                JOIN domains AS d ON m.domain = d.domain
                JOIN users AS u ON m.owner = u.username
                WHERE m.address = ?1
                  AND m.active = true
                  AND d.active = true
                  AND u.active = true
              -- Then select the target of a matching alias
              -- but make sure that all related parts are active.
              UNION
              SELECT a.target AS name
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
              -- Finally, select any catch_all address that would catch this.
              -- Again make sure everything is active.
              UNION
              SELECT d.catch_all AS name
                FROM domains AS d
                JOIN mailboxes AS m ON d.catch_all = m.address
                JOIN users AS u ON m.owner = u.username
                WHERE ?1 = ('@' || d.domain)
                  AND d.active = true
                  AND m.active = true
                  AND u.active = true

              -- This alternative catch-all query would expand catch-alls directly, but would
              -- also require sorting the resulting table by precedence and LIMIT 1
              -- to always return just one result.
              -- UNION
              -- SELECT d.catch_all AS name
              --   FROM domains AS d
              --   JOIN mailboxes AS m ON d.catch_all = m.address
              --   JOIN users AS u ON m.owner = u.username
              --   WHERE ?1 LIKE ('%@' || d.domain)
              --     AND d.active = true
              --     AND m.active = true
              --     AND u.active = true
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
            requests = "2000/1m";
            concurrent = 4;
          };
        };

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
