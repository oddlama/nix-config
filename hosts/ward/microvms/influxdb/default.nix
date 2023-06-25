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
    influxdb2.url = sentinelCfg.providedDomains.influxdb;
    influxdb2.organization = "servers";
    influxdb2.bucket = "telegraf";
  };

  networking.nftables.firewall.rules = lib.mkForce {
    sentinel-to-local.allowedTCPPorts = [influxdbPort];
  };

  nodes.sentinel = {
    providedDomains.influxdb = influxdbDomain;

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
