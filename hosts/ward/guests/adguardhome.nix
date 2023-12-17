{
  config,
  lib,
  nodes,
  pkgs,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  adguardhomeDomain = "adguardhome.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [config.services.adguardhome.settings.bind_port];

  nodes.sentinel = {
    networking.providedDomains.adguard = adguardhomeDomain;

    services.nginx = {
      upstreams.adguardhome = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:${toString config.services.adguardhome.settings.bind_port}" = {};
        extraConfig = ''
          zone adguardhome 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${adguardhomeDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        oauth2.enable = true;
        oauth2.allowedGroups = ["access_adguardhome"];
        locations."/" = {
          proxyPass = "http://adguardhome";
          proxyWebsockets = true;
        };
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = [53];
    allowedUDPPorts = [53];
  };

  services.adguardhome = {
    enable = true;
    # TODO allow mutable settings, replace 123.123.123.123 with
    # simpler sed dns.host_addr logic.
    mutableSettings = false;
    settings = {
      bind_host = "0.0.0.0";
      bind_port = 3000;
      dns = {
        bind_hosts = [
          # This dummy address passes the configuration check and will
          # later be replaced by the actual interface address.
          "123.123.123.123"
        ];
        # allowed_clients = [
        # ];
        #trusted_proxied = [];
        ratelimit = 60;
        upstream_dns = [
          "1.1.1.1"
          "2606:4700:4700::1111"
          "8.8.8.8"
          "2001:4860:4860::8844"
        ];
        bootstrap_dns = [
          "1.1.1.1"
          "2606:4700:4700::1111"
          "8.8.8.8"
          "2001:4860:4860::8844"
        ];
        dhcp.enabled = false;
      };
    };
  };

  systemd.services.adguardhome = {
    preStart = lib.mkAfter ''
      INTERFACE_ADDR=$(${pkgs.iproute2}/bin/ip -family inet -brief addr show wan | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+")
      sed -i -e "s/123.123.123.123/$INTERFACE_ADDR/" "$STATE_DIRECTORY/AdGuardHome.yaml"
    '';
    serviceConfig.RestartSec = lib.mkForce "600"; # Retry every 10 minutes
  };
}
