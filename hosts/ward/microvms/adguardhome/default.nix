{
  config,
  lib,
  nodes,
  utils,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  adguardDomain = "adguardhome.${sentinelCfg.repo.secrets.local.personalDomain}";
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
    proxiedDomains.adguard = adguardDomain;

    globalConfig = ''
      security {
        authorization policy mypolicy {
          set auth url https://auth.myfiosgateway.com:8443/
          allow roles authp/user
          crypto key verify {env.JWT_SHARED_KEY}
        }
      }
    '';

    services.caddy.virtualHosts.${adguardDomain} = {
      useACMEHost = sentinelCfg.lib.extra.matchingWildcardCert adguardDomain;
      extraConfig = ''
        import common
        reverse_proxy {
          to http://${config.services.adguardhome.settings.bind_host}:${toString config.services.adguardhome.settings.bind_port}
          header_up X-Real-IP {remote_host}
        }
      '';
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
