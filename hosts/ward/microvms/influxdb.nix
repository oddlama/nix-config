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
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [influxdbPort];

  nodes.sentinel = {
    networking.providedDomains.influxdb = influxdbDomain;

    services.nginx = {
      upstreams.influxdb = {
        servers."${config.services.influxdb2.settings.http-bind-address}" = {};
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

  services.influxdb2 = {
    enable = true;
    settings = {
      reporting-disabled = true;
      http-bind-address = "${config.meta.wireguard.proxy-sentinel.ipv4}:${toString influxdbPort}";
    };
  };

  systemd.services.influxdb2.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "proxy-sentinel"}.device"];
}
