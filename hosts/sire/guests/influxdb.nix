{
  config,
  lib,
  nodes,
  pkgs,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  influxdbDomain = "influxdb.${sentinelCfg.repo.secrets.local.personalDomain}";
  influxdbPort = 8086;
in {
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [influxdbPort];

  nodes.sentinel = {
    networking.providedDomains.influxdb = influxdbDomain;

    services.nginx = {
      upstreams.influxdb = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:${toString influxdbPort}" = {};
        extraConfig = ''
          zone influxdb 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${influxdbDomain} = let
        accessRules = ''
          satisfy any;
          ${lib.concatMapStrings (ip: "allow ${ip};\n") sentinelCfg.meta.wireguard.proxy-sentinel.server.reservedAddresses}
          deny all;
        '';
      in {
        forceSSL = true;
        useACMEWildcardHost = true;
        oauth2.enable = true;
        oauth2.allowedGroups = ["access_influxdb"];
        locations."/" = {
          proxyPass = "http://influxdb";
          proxyWebsockets = true;
          extraConfig = accessRules;
        };
        locations."/api/v2/write" = {
          proxyPass = "http://influxdb/api/v2/write";
          proxyWebsockets = true;
          extraConfig = ''
            ${accessRules}
            access_log off;
          '';
        };
      };
    };
  };

  age.secrets.influxdb-admin-password = {
    generator.script = "alnum";
    mode = "440";
    group = "influxdb2";
  };

  age.secrets.influxdb-admin-token = {
    generator.script = "alnum";
    mode = "440";
    group = "influxdb2";
  };

  age.secrets.influxdb-user-telegraf-token = {
    generator.script = "alnum";
    mode = "440";
    group = "influxdb2";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/influxdb2";
      user = "influxdb2";
      group = "influxdb2";
      mode = "0700";
    }
  ];

  services.influxdb2 = {
    enable = true;
    settings = {
      reporting-disabled = true;
      http-bind-address = "0.0.0.0:${toString influxdbPort}";
    };
    provision = {
      enable = true;
      initialSetup = {
        organization = "default";
        bucket = "default";
        passwordFile = config.age.secrets.influxdb-admin-password.path;
        tokenFile = config.age.secrets.influxdb-admin-token.path;
      };
      organizations.machines.buckets.telegraf = {};
    };
  };

  environment.systemPackages = [pkgs.influxdb2-cli];

  systemd.services.grafana.serviceConfig.RestartSec = "600"; # Retry every 10 minutes
}
