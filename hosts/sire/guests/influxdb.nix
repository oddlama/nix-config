{
  config,
  globals,
  lib,
  pkgs,
  ...
}:
let
  influxdbDomain = "influxdb.${globals.domains.me}";
  influxdbPort = 8086;
in
{
  globals.wireguard.proxy-sentinel.hosts.${config.node.name}.firewallRuleForNode.sentinel.allowedTCPPorts =
    [ influxdbPort ];
  globals.wireguard.proxy-home.hosts.${config.node.name}.firewallRuleForNode.ward-web-proxy.allowedTCPPorts =
    [ influxdbPort ];

  age.secrets.github-access-token = {
    rekeyFile = config.node.secretsDir + "/github-access-token.age";
    mode = "440";
    group = "telegraf";
  };

  meta.telegraf.secrets."@GITHUB_ACCESS_TOKEN@" = config.age.secrets.github-access-token.path;
  services.telegraf.extraConfig.outputs.influxdb_v2.urls = lib.mkForce [
    "http://localhost:${toString influxdbPort}"
  ];

  services.telegraf.extraConfig.inputs = {
    github = {
      interval = "10m";
      access_token = "@GITHUB_ACCESS_TOKEN@";
      repositories = [
        "oddlama/agenix-rekey"
        "oddlama/autokernel"
        "oddlama/gentoo-install"
        "oddlama/idmail"
        "oddlama/nix-config"
        "oddlama/nix-topology"
        "oddlama/vane"
      ];
    };
  };

  globals.services.influxdb.domain = influxdbDomain;

  nodes.sentinel = {
    services.nginx = {
      upstreams.influxdb = {
        servers."${
          globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
        }:${toString influxdbPort}" =
          { };
        extraConfig = ''
          zone influxdb 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "InfluxDB";
        };
      };
      virtualHosts.${influxdbDomain} =
        let
          accessRules = ''
            allow ${globals.wireguard.proxy-sentinel.cidrv4};
            allow ${globals.wireguard.proxy-sentinel.cidrv6};
            deny all;
          '';
        in
        {
          forceSSL = true;
          useACMEWildcardHost = true;
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

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams.influxdb = {
        servers."${globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4}:${toString influxdbPort}" =
          { };
        extraConfig = ''
          zone influxdb 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "InfluxDB";
        };
      };
      virtualHosts.${influxdbDomain} =
        let
          accessRules = ''
            allow ${globals.net.home-lan.vlans.services.cidrv4};
            allow ${globals.net.home-lan.vlans.services.cidrv6};
            allow ${globals.wireguard.proxy-home.cidrv4};
            allow ${globals.wireguard.proxy-home.cidrv6};
            deny all;
          '';
        in
        {
          forceSSL = true;
          useACMEWildcardHost = true;
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

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/influxdb2";
      user = "influxdb2";
      group = "influxdb2";
      mode = "0700";
    }
  ];

  environment.systemPackages = [ pkgs.influxdb2-cli ];

  topology.self.services.influxdb2.info = "https://${influxdbDomain}";
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
      organizations.machines.buckets.telegraf = { };
    };
  };

  systemd.services.influxdb2.serviceConfig.RestartSec = "60"; # Retry every minute
}
