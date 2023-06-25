{
  config,
  lib,
  nodes,
  utils,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  influxdbDomain = "influxdb.${sentinelCfg.repo.secrets.local.personalDomain}";
  influxdbPort = 8086;
in {
  microvm.mem = 1024;

  imports = [
    ../../../../modules/proxy-via-sentinel.nix
  ];

  extra.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${sentinelCfg.extra.wireguard.proxy-sentinel.ipv4} = [sentinelCfg.providedDomains.influxdb];
  extra.telegraf = {
    enable = true;
    influxdb2.domain = sentinelCfg.providedDomains.influxdb;
    influxdb2.organization = "servers";
    influxdb2.bucket = "telegraf";
  };

  networking.nftables.firewall.rules = lib.mkForce {
    sentinel-to-local.allowedTCPPorts = [influxdbPort];
  };

  nodes.sentinel = {
    providedDomains.influxdb = influxdbDomain;

    # Not actually used on the system, but to allow us to provision tokens
    # when generating secrets.
    age.secrets.admin-influxdb-basic-auth-password = {
      rekeyFile = ./secrets/admin-influxdb-basic-auth-password.age;
      generator = "alnum";
      mode = "000";
    };

    age.secrets.influxdb-basic-auth-hashes = {
      rekeyFile = ./secrets/influxdb-basic-auth-hashes.age;
      # Copy only the script so the dependencies can be added by the nodes
      # that define passwords (using distributed-config).
      generator = {
        inherit (config.age.generators.basic-auth) script;
        dependencies = [sentinelCfg.age.secrets.admin-influxdb-basic-auth-password];
      };
      mode = "440";
      group = "nginx";
    };

    services.nginx = {
      upstreams.influxdb = {
        servers."${config.services.influxdb2.settings.http-bind-address}" = {};
        extraConfig = ''
          zone influxdb 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${influxdbDomain} = {
        forceSSL = true;
        useACMEHost = sentinelCfg.lib.extra.matchingWildcardCert influxdbDomain;
        oauth2.enable = true;
        oauth2.allowedGroups = ["access_influxdb"];
        locations."/" = {
          proxyPass = "http://influxdb";
          proxyWebsockets = true;
          extraConfig = ''
            satisfy any;
            auth_basic "Authentication required";
            auth_basic_user_file ${sentinelCfg.age.secrets.influxdb-basic-auth-hashes.path};
            ${lib.concatMapStrings (ip: "allow ${ip};\n") sentinelCfg.extra.wireguard.proxy-sentinel.server.reservedAddresses}
            deny all;
          '';
        };
      };
    };
  };

  services.influxdb2 = {
    enable = true;
    settings = {
      reporting-disabled = true;
      http-bind-address = "${config.extra.wireguard.proxy-sentinel.ipv4}:${toString influxdbPort}";
    };
  };

  systemd.services.influxdb2.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "proxy-sentinel"}.device"];
}
