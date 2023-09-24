{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    attrNames
    flip
    isAttrs
    mapAttrs
    mkMerge
    mkOption
    optionals
    types
    ;
in {
  # Give agenix access to the hostkey independent of impermanence activation
  age.identityPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];

  # Expose a home manager module for each user that allows extending
  # environment.persistence.${sourceDir}.users.${userName} simply by
  # specifying home.persistence.${sourceDir} in home manager.
  home-manager.sharedModules = [
    {
      options.home.persistence = mkOption {
        description = "Additional persistence config for the given source path";
        default = {};
        type = types.attrsOf (types.submodule {
          options = {
            files = mkOption {
              description = "Additional files to persist via NixOS impermanence.";
              type = types.listOf (types.either types.attrs types.str);
              default = [];
            };

            directories = mkOption {
              description = "Additional directories to persist via NixOS impermanence.";
              type = types.listOf (types.either types.attrs types.str);
              default = [];
            };
          };
        });
      };
    }
  ];

  # For each user that has a home-manager config, merge the locally defined
  # persistence options that we defined above.
  imports = let
    mkUserFiles = map (x:
      {parentDirectory.mode = "700";}
      // (
        if isAttrs x
        then x
        else {file = x;}
      ));
    mkUserDirs = map (x:
      {mode = "700";}
      // (
        if isAttrs x
        then x
        else {directory = x;}
      ));
  in [
    {
      environment.persistence = mkMerge (
        flip map
        (attrNames config.home-manager.users)
        (
          user: let
            hmUserCfg = config.home-manager.users.${user};
          in
            flip mapAttrs hmUserCfg.home.persistence
            (_: sourceCfg: {
              users.${user} = {
                files = mkUserFiles sourceCfg.files;
                directories = mkUserDirs sourceCfg.directories;
              };
            })
        )
      );
    }
  ];

  # State that should be kept across reboots, but is otherwise
  # NOT important information in any way that needs to be backed up.
  fileSystems."/state".neededForBoot = true;
  environment.persistence."/state" = {
    hideMounts = true;
    directories =
      [
        "/var/tmp/agenix-rekey"
        "/var/lib/systemd"
        "/var/log"
        #{ directory = "/tmp"; mode = "1777"; }
        #{ directory = "/var/tmp"; mode = "1777"; }
        "/var/spool"
      ]
      ++ optionals config.networking.wireless.iwd.enable [
        {
          directory = "/var/lib/iwd";
          mode = "0700";
        }
      ];
  };

  # State that should be kept forever, and backed up accordingly.
  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist" = {
    hideMounts = true;
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
    directories =
      [
        "/var/lib/nixos"
      ]
      ++ optionals config.security.acme.acceptTerms [
        {
          directory = "/var/lib/acme";
          user = "acme";
          group = "acme";
          mode = "0755";
        }
      ]
      ++ optionals config.services.printing.enable [
        {
          directory = "/var/lib/cups";
          mode = "0700";
        }
      ]
      ++ optionals config.services.fail2ban.enable [
        {
          directory = "/var/lib/fail2ban";
          user = "fail2ban";
          group = "fail2ban";
          mode = "0750";
        }
      ]
      ++ optionals config.services.postgresql.enable [
        {
          directory = "/var/lib/postgresql";
          user = "postgres";
          group = "postgres";
          mode = "0700";
        }
      ]
      ++ optionals config.services.gitea.enable [
        {
          directory = config.services.gitea.stateDir;
          user = "gitea";
          group = "gitea";
          mode = "0700";
        }
      ]
      ++ optionals config.services.caddy.enable [
        {
          directory = config.services.caddy.dataDir;
          user = "caddy";
          group = "caddy";
          mode = "0700";
        }
      ]
      ++ optionals config.services.loki.enable [
        {
          directory = "/var/lib/loki";
          user = "loki";
          group = "loki";
          mode = "0700";
        }
      ]
      ++ optionals config.services.grafana.enable [
        {
          directory = config.services.grafana.dataDir;
          user = "grafana";
          group = "grafana";
          mode = "0700";
        }
      ]
      ++ optionals config.services.kanidm.enableServer [
        {
          directory = "/var/lib/kanidm";
          user = "kanidm";
          group = "kanidm";
          mode = "0700";
        }
      ]
      ++ optionals config.services.vaultwarden.enable [
        {
          directory = "/var/lib/vaultwarden";
          user = "vaultwarden";
          group = "vaultwarden";
          mode = "0700";
        }
      ]
      ++ optionals config.services.influxdb2.enable [
        {
          directory = "/var/lib/influxdb2";
          user = "influxdb2";
          group = "influxdb2";
          mode = "0700";
        }
      ]
      ++ optionals config.services.telegraf.enable [
        {
          directory = "/var/lib/telegraf";
          user = "telegraf";
          group = "telegraf";
          mode = "0700";
        }
      ]
      ++ optionals config.services.adguardhome.enable [
        {
          directory = "/var/lib/private/AdGuardHome";
          mode = "0700";
        }
      ]
      ++ optionals config.services.esphome.enable [
        {
          directory = "/var/lib/private/esphome";
          mode = "0700";
        }
      ]
      ++ optionals config.services.home-assistant.enable [
        {
          directory = config.services.home-assistant.configDir;
          user = "hass";
          group = "hass";
          mode = "0700";
        }
      ];
  };
}
