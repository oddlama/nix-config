{
  config,
  lib,
  ...
}: {
  # Give agenix access to the hostkey independent of impermanence activation
  age.identityPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];

  # State that should be kept across reboots, but is otherwise
  # NOT important information in any way that needs to be backed up.
  environment.persistence."/state" = {
    hideMounts = true;
    directories =
      [
        {
          directory = "/var/lib/systemd";
          user = "root";
          group = "root";
          mode = "0755";
        }
        {
          directory = "/var/log";
          user = "root";
          group = "root";
          mode = "0755";
        }
        #{ directory = "/tmp"; user = "root"; group = "root"; mode = "1777"; }
        #{ directory = "/var/tmp"; user = "root"; group = "root"; mode = "1777"; }
        {
          directory = "/var/spool";
          user = "root";
          group = "root";
          mode = "0755";
        }
      ]
      ++ lib.optionals config.networking.wireless.iwd.enable [
        {
          directory = "/var/lib/iwd";
          user = "root";
          group = "root";
          mode = "0700";
        }
      ];
  };

  # State that should be kept forever, and backed up accordingly.
  environment.persistence."/persist" = {
    hideMounts = true;
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
    directories =
      [
        {
          directory = "/var/lib/nixos";
          user = "root";
          group = "root";
          mode = "0755";
        }
      ]
      ++ lib.optionals config.security.acme.acceptTerms [
        {
          directory = "/var/lib/acme";
          user = "acme";
          group = "acme";
          mode = "0755";
        }
      ]
      ++ lib.optionals config.services.printing.enable [
        {
          directory = "/var/lib/cups";
          user = "root";
          group = "root";
          mode = "0700";
        }
      ]
      ++ lib.optionals config.services.fail2ban.enable [
        {
          directory = "/var/lib/fail2ban";
          user = "fail2ban";
          group = "fail2ban";
          mode = "0750";
        }
      ]
      ++ lib.optionals config.services.postgresql.enable [
        {
          directory = "/var/lib/postgresql";
          user = "postgres";
          group = "postgres";
          mode = "0700";
        }
      ]
      ++ lib.optionals config.services.gitea.enable [
        {
          directory = config.services.gitea.stateDir;
          user = "gitea";
          group = "gitea";
          mode = "0700";
        }
      ]
      ++ lib.optionals config.services.caddy.enable [
        {
          directory = config.services.caddy.dataDir;
          user = "caddy";
          group = "caddy";
          mode = "0700";
        }
      ]
      ++ lib.optionals config.services.loki.enable [
        {
          directory = "/var/lib/loki";
          user = "loki";
          group = "loki";
          mode = "0700";
        }
      ]
      ++ lib.optionals config.services.grafana.enable [
        {
          directory = config.services.grafana.dataDir;
          user = "grafana";
          group = "grafana";
          mode = "0700";
        }
      ]
      ++ lib.optionals config.services.kanidm.enableServer [
        {
          directory = "/var/lib/kanidm";
          user = "kanidm";
          group = "kanidm";
          mode = "0700";
        }
      ]
      ++ lib.optionals config.services.vaultwarden.enable [
        {
          directory = "/var/lib/vaultwarden";
          user = "vaultwarden";
          group = "vaultwarden";
          mode = "0700";
        }
      ]
      ++ lib.optionals config.services.influxdb2.enable [
        {
          directory = "/var/lib/influxdb2";
          user = "influxdb2";
          group = "influxdb2";
          mode = "0700";
        }
      ];
  };
}
