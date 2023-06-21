{
  config,
  lib,
  nodes,
  utils,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  adguardhomeDomain = "adguardhome.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  imports = [
    ../../../../modules/proxy-via-sentinel.nix
  ];

  extra.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  networking.nftables.firewall.rules = lib.mkForce {
    sentinel-to-local.allowedTCPPorts = [config.services.adguardhome.settings.bind_port];
  };

  nodes.sentinel = {
    proxiedDomains.adguard = adguardhomeDomain;

    extra.oauth2_proxy.nginx.virtualHosts."${adguardhomeDomain}".allowedGroups = ["adguardhome"];
    services.nginx = {
      upstreams.adguardhome = {
        servers."${config.services.adguardhome.settings.bind_host}:${toString config.services.adguardhome.settings.bind_port}" = {};
        extraConfig = ''
          zone adguardhome 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${adguardhomeDomain} = {
        forceSSL = true;
        useACMEHost = sentinelCfg.lib.extra.matchingWildcardCert adguardhomeDomain;
        locations."/" = {
          proxyPass = "https://adguardhome";
          proxyWebsockets = true;
        };
      };
    };
  };

  services.adguardhome = {
    enable = true;
    settings = {
      bind_host = config.extra.wireguard.proxy-sentinel.ipv4;
      bind_port = 3000;
      #dns = {
      #  edns_client_subnet.enabled = false;
      #  bind_hosts = [ "127.0.0.1" ];
      #  bootstrap_dns = [
      #    "8.8.8.8"
      #    "8.8.4.4"
      #    "2001:4860:4860::8888"
      #    "2001:4860:4860::8844"
      #  ];
      #};
    };
  };

  systemd.services.influxdb.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "proxy-sentinel"}.device"];
}
