{
  config,
  lib,
  ...
}: {
  # State that should be kept across reboots, but is otherwise
  # NOT important information in any way that needs to be backed up.
  #environment.persistence."/nix/state" = {
  #  hideMounts = true;
  #  files = [
  #  ];
  #  directories = [
  #  ];
  #};

  # Give agenix access to the hostkey independent of impermanence activation
  age.identityPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];

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
          mode = "0777";
        }
      ]
      ++ lib.optionals config.networking.wireless.iwd.enable [
        {
          directory = "/var/lib/iwd";
          user = "root";
          group = "root";
          mode = "0700";
        }
      ]
      ++ lib.optionals (config.services.kea.dhcp4.enable || config.services.kea.dhcp6.enable) [
        {
          directory = "/var/lib/kea";
          user = "kea";
          group = "kea";
          mode = "0755";
        }
      ]
      ++ lib.optionals config.services.gitea.enable [
        {
          directory = "/var/lib/gitea";
          user = "gitea";
          group = "gitea";
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
          mode = "0755";
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
      ++ lib.optionals config.services.opendkim.enable [
        {
          directory = "/var/lib/postgresql";
          user = "postgres";
          group = "postgres";
          mode = "0755";
        }
      ];
  };
}
