{
  config,
  lib,
  nodes,
  pkgs,
  utils,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  kanidmDomain = "auth.${sentinelCfg.repo.secrets.local.personalDomain}";
  kanidmPort = 8300;
in {
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
    sentinel-to-local.allowedTCPPorts = [kanidmPort];
  };

  age.secrets."kanidm-self-signed.crt" = {
    rekeyFile = ./secrets/kanidm-self-signed.crt.age;
    mode = "440";
    group = "kanidm";
  };

  age.secrets."kanidm-self-signed.key" = {
    rekeyFile = ./secrets/kanidm-self-signed.key.age;
    mode = "440";
    group = "kanidm";
  };

  nodes.sentinel = {
    providedDomains.kanidm = kanidmDomain;

    services.nginx = {
      upstreams.kanidm = {
        servers."${config.services.kanidm.serverSettings.bindaddress}" = {};
        extraConfig = ''
          zone kanidm 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${kanidmDomain} = {
        forceSSL = true;
        useACMEHost = sentinelCfg.lib.extra.matchingWildcardCert kanidmDomain;
        locations."/".proxyPass = "https://kanidm";
        # Allow using self-signed certs to satisfy kanidm's requirement
        # for TLS connections. (Although this is over wireguard anyway)
        extraConfig = ''
          proxy_ssl_verify off;
        '';
      };
    };
  };

  services.kanidm = {
    enableServer = true;
    # enablePAM = true;
    serverSettings = {
      domain = kanidmDomain;
      origin = "https://${kanidmDomain}";
      tls_chain = config.age.secrets."kanidm-self-signed.crt".path;
      tls_key = config.age.secrets."kanidm-self-signed.key".path;
      bindaddress = "${config.extra.wireguard.proxy-sentinel.ipv4}:${toString kanidmPort}";
      trust_x_forward_for = true;
    };
  };

  environment.systemPackages = [pkgs.kanidm];

  services.kanidm = {
    enableClient = true;
    clientSettings = {
      uri = config.services.kanidm.serverSettings.origin;
      verify_ca = true;
      verify_hostnames = true;
    };
  };

  systemd.services.kanidm.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "proxy-sentinel"}.device"];
}
