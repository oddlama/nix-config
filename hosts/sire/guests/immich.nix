{
  config,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  immichDomain = "immich.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [config.services.immich.web_port];

  nodes.sentinel = {
    networking.providedDomains.immich = immichDomain;

    services.nginx = {
      upstreams.immich = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:${toString config.services.immich.settings.bind_port}" = {};
        extraConfig = ''
          zone immich 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${immichDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        oauth2.enable = true;
        oauth2.allowedGroups = ["access_immich"];
        locations."/" = {
          proxyPass = "http://immich";
          proxyWebsockets = true;
        };
      };
    };
  };

  services.immich = {
    enable = true;
  };

  systemd.services.grafana.serviceConfig.RestartSec = "600"; # Retry every 10 minutes
}
