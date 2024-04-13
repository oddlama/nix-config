{
  config,
  pkgs,
  lib,
  ...
}: let
  mailDomains = config.repo.secrets.global.domains.mail;
  primaryDomain = mailDomains.primary;
  backupDir = "/var/cache/backups/maddy";
in {
  systemd.tmpfiles.settings."10-maddy".${backupDir}.d = {
    inherit (config.services.maddy) user group;
    mode = "0770";
  };

  environment.persistence."/state".directories = [
    {
      directory = backupDir;
      inherit (config.services.maddy) user group;
      mode = "0750";
    }
  ];

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/maddy";
      inherit (config.services.maddy) user group;
      mode = "0750";
    }
  ];

  # FIXME: hetzner storagebox backup
  services.nginx.virtualHosts = lib.mkMerge [
    # For each mail domain, add MTA STS entry via nginx
    (lib.genAttrs (map (x: "mta-sts.${x}") mailDomains.all) (domain: {
      forceSSL = true;
      useACMEWildcardHost = true;
      locations."=/.well-known/mta-sts.txt".alias = pkgs.writeText "mta-sts.${domain}.txt" ''
        version: STSv1
        mode: enforce
        mx: mx1.${primaryDomain}
        max_age: 86400
      '';
    }))
    # For each mail domain, add an autoconfig xml file for Thunderbird
    (lib.genAttrs (map (x: "autoconfig.${x}") mailDomains.all) (domain: {
      forceSSL = true;
      useACMEWildcardHost = true;
      locations."=/mail/config-v1.1.xml".alias =
        pkgs.writeText "autoconfig.${domain}.xml"
        /*
        xml
        */
        ''
          <?xml version="1.0" encoding="UTF-8"?>
          <clientConfig version="1.1">
            <emailProvider id="${domain}">
              <domain>${domain}</domain>
              <displayName>%EMAILADDRESS%</displayName>
              <displayShortName>%EMAILLOCALPART%</displayShortName>
              <incomingServer type="imap">
                <hostname>mail.${primaryDomain}</hostname>
                <port>993</port>
                <socketType>SSL</socketType>
                <authentication>password-cleartext</authentication>
                <username>%EMAILADDRESS%</username>
              </incomingServer>
              <outgoingServer type="smtp">
                <hostname>mail.${primaryDomain}</hostname>
                <port>465</port>
                <socketType>SSL</socketType>
                <authentication>password-cleartext</authentication>
                <username>%EMAILADDRESS%</username>
              </outgoingServer>
            </emailProvider>
          </clientConfig>
        '';
    }))
  ];

  networking.firewall.allowedTCPPorts = [25 465 993];
  users.groups.acme.members = ["maddy"];

  services.maddy = {
    enable = true;
    hostname = "mx1.${primaryDomain}";
    inherit primaryDomain;
    localDomains = mailDomains.all;
    tls = {
      loader = "file";
      certificates = [
        {
          keyPath = "${config.security.acme.certs.${primaryDomain}.directory}/key.pem";
          certPath = "${config.security.acme.certs.${primaryDomain}.directory}/fullchain.pem";
        }
      ];
    };
    #ensureCredentials = {
    #  "me@${primaryDomain}".passwordFile = ...;
    #};
    #ensureAccounts = [
    #  "me@${primaryDomain}"
    #];
    config =
      /*
      bash
      */
      ''
        auth.pass_table local_authdb {
            table sql_table {
                driver sqlite3
                dsn mailboxes.db
                table_name users
            }
        }

        storage.imapsql local_mailboxes {
            driver sqlite3
            dsn imap.db
        }

        table.chain local_rewrites {
            optional_step sql_query {
                driver sqlite3
                dsn mailboxes.db
                lookup "SELECT alias FROM aliases WHERE address = $1"
            }
        }

        msgpipeline local_routing {
            destination $(local_domains) {
                modify {
                    replace_rcpt &local_rewrites
                }

                deliver_to &local_mailboxes
            }

            default_destination {
                reject 550 5.1.1 "User doesn't exist"
            }
        }

        # ----------------------------------------------------------------------------
        # Endpoints

        imap tls://0.0.0.0:993 {
            auth &local_authdb
            storage &local_mailboxes
        }

        # SMTP for incoming mails from other servers.
        # Allows anyone to connect and give us local mail, but doesn't allow message relaying.
        smtp tcp://0.0.0.0:25 {
            limits {
                # Up to 20 msgs/sec across max. 10 SMTP connections.
                all rate 20 1s
                all concurrency 10
            }

            dmarc yes
            max_message_size 256M
            check {
                require_mx_record
                dkim
                spf
            }

            source $(local_domains) {
                reject 501 5.1.8 "Use Submission for outgoing SMTP"
            }
            default_source {
                destination $(local_domains) {
                    deliver_to &local_routing
                }
                default_destination {
                    reject 550 5.1.1 "User doesn't exist"
                }
            }
        }

        # Submission with implicit TLS for authenticated users.
        # Allows only authenticated users, and allows message relaying.
        # Contrary to popular belief, port 465 is [NOT deprecated](https://datatracker.ietf.org/doc/html/rfc8314#section-7.3),
        # and has been assigned for "Message Submission over TLS protocol",
        # I neither need nor want to use STARTTLS.
        submission tls://0.0.0.0:465 {
            limits {
                # Up to 50 msgs/sec across any amount of SMTP connections.
                all rate 50 1s
            }

            auth &local_authdb

            source $(local_domains) {
                check {
                    authorize_sender {
                        prepare_email &local_rewrites
                        user_to_email identity
                    }
                }

                destination $(local_domains) {
                    modify {
                        dkim $(local_domains) default
                    }
                    deliver_to &local_routing
                }
                default_destination {
                    modify {
                        dkim $(local_domains) default
                    }
                    deliver_to &remote_queue
                }
            }
            default_source {
                reject 501 5.1.8 "Non-local sender domain"
            }
        }

        # ----------------------------------------------------------------------------
        # Outbound configuration

        target.queue remote_queue {
            target &outbound_delivery

            autogenerated_msg_domain $(primary_domain)
            bounce {
                destination $(local_domains) {
                    deliver_to &local_routing
                }
                default_destination {
                    reject 550 5.0.0 "Refusing to send DSNs to non-local addresses"
                }
            }
        }

        target.remote outbound_delivery {
            limits {
                # Up to 20 msgs/sec across max. 10 SMTP connections
                # for each recipient domain.
                destination rate 20 1s
                destination concurrency 10
            }
            mx_auth {
                dane
                mtasts {
                    cache fs
                    fs_dir mtasts_cache/
                }
                local_policy {
                    min_tls_level encrypted
                    min_mx_level none
                }
            }
        }
      '';
  };
}
