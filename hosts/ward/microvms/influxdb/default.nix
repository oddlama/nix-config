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
  imports = [
    ../../../../modules/proxy-via-sentinel.nix
  ];

  extra.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  networking.nftables.firewall.rules = lib.mkForce {
    sentinel-to-local.allowedTCPPorts = [influxdbPort];
  };

  nodes.sentinel = {
    proxiedDomains.influxdb = influxdbDomain;

    age.secrets.influxdb-basic-auth-hashes = {
      rekeyFile = ./secrets/influxdb-basic-auth-hashes.age;
      # Copy only the script so the dependencies can be added by the nodes
      # that define passwords (using distributed-config).
      generator.script = config.age.generators.basic-auth.script;
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
        locations."/" = {
          proxyPass = "http://influxdb";
          proxyWebsockets = true;
          extraConfig = ''
            auth_basic "Authentication required";
            auth_basic_user_file ${sentinelCfg.age.secrets.influxdb-basic-auth-hashes.path};

            proxy_read_timeout 1800s;
            proxy_connect_timeout 1600s;

            access_log off;
          '';
        };
        locations."= /ready" = {
          proxyPass = "http://influxdb";
          extraConfig = ''
            auth_basic off;
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
      http-bind-address = "${config.extra.wireguard.proxy-sentinel.ipv4}:${toString influxdbPort}";
    };
  };

  systemd.services.influxdb2.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "proxy-sentinel"}.device"];
}
