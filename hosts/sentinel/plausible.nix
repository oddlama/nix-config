{
  config,
  lib,
  globals,
  ...
}: let
  plausibleDomain = "analytics.${globals.domains.me}";
in {
  age.secrets.plausible-secret = {
    generator.script = args: "${args.pkgs.openssl}/bin/openssl rand -base64 64";
    mode = "440";
    group = "plausible";
  };

  age.secrets.plausible-admin-pw = {
    generator.script = "alnum";
    mode = "440";
    group = "plausible";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/clickhouse";
      mode = "0750";
      user = "clickhouse";
      group = "clickhouse";
    }
    {
      directory = "/var/lib/plausible";
      mode = "0750";
      user = "plausible";
      group = "plausible";
    }
  ];

  services.clickhouse.enable = true;
  environment.etc = {
    # With changes from https://theorangeone.net/posts/calming-down-clickhouse/
    "clickhouse-server/config.d/custom.xml".source = lib.mkForce ./clickhouse-config.xml;
    "clickhouse-server/users.d/custom.xml".source = lib.mkForce ./clickhouse-users.xml;
  };

  globals.services.plausible.domain = plausibleDomain;
  services.plausible = {
    enable = true;

    server = {
      port = 8545;
      baseUrl = "https://${plausibleDomain}";
      disableRegistration = true;
      secretKeybaseFile = config.age.secrets.plausible-secret.path;
    };

    adminUser = {
      activate = true;
      name = "admin";
      email = "plausible@${globals.domains.me}";
      passwordFile = config.age.secrets.plausible-admin-pw.path;
    };
  };

  services.nginx = {
    upstreams.plausible = {
      servers."127.0.0.1:${toString config.services.plausible.server.port}" = {};
      extraConfig = ''
        zone plausible 64k;
        keepalive 2;
      '';
      monitoring = {
        enable = true;
        expectedBodyRegex = "Plausible";
      };
    };
    virtualHosts.${plausibleDomain} = {
      forceSSL = true;
      useACMEWildcardHost = true;
      oauth2.enable = true;
      oauth2.allowedGroups = ["access_analytics"];
      locations."/".proxyPass = "http://plausible";
      locations."= /js/script.js" = {
        proxyPass = "http://plausible";
        extraConfig = ''
          auth_request off;
        '';
      };
      locations."= /api/event" = {
        proxyPass = "http://plausible";
        extraConfig = ''
          proxy_http_version 1.1;
          auth_request off;
        '';
      };
    };
  };

  services.epmd.enable = lib.mkForce false;
  systemd.services.plausible = {
    environment = {
      STORAGE_DIR = lib.mkForce "/run/plausible/elixir_tzdata";
      RELEASE_TMP = lib.mkForce "/run/plausible/tmp";
      HOME = lib.mkForce "/run/plausible";
    };
    serviceConfig = {
      RestartSec = "60"; # Retry every minute
      DynamicUser = lib.mkForce false;
      User = "plausible";
      Group = "plausible";
      StateDirectory = lib.mkForce "plausible";
      RuntimeDirectory = "plausible";
      WorkingDirectory = lib.mkForce "/run/plausible";
    };
  };

  users.groups.plausible = {};
  users.users.plausible = {
    group = "plausible";
    isSystemUser = true;
    home = "/var/lib/plausible";
  };
}
