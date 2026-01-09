{
  config,
  globals,
  lib,
  ...
}:
let
  adguardhomeDomain = "adguardhome.${globals.domains.me}";
in
{
  globals.wireguard.proxy-sentinel.hosts.${config.node.name}.firewallRuleForNode.sentinel.allowedTCPPorts =
    [
      config.services.adguardhome.port
    ];

  # Allow home-assistant to access it directly
  globals.wireguard.proxy-home.hosts.${config.node.name}.firewallRuleForNode.sausebiene.allowedTCPPorts =
    [
      config.services.adguardhome.port
    ];

  globals.services.adguardhome.domain = adguardhomeDomain;
  globals.monitoring.dns.adguardhome = {
    server = globals.net.home-lan.vlans.services.hosts.ward-adguardhome.ipv4;
    domain = ".";
    network = "home-lan.vlans.services";
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams.adguardhome = {
        servers."${
          globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
        }:${toString config.services.adguardhome.port}" =
          { };
        extraConfig = ''
          zone adguardhome 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "AdGuard Home";
        };
      };
      virtualHosts.${adguardhomeDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        oauth2.enable = true;
        oauth2.allowedGroups = [ "access_adguardhome" ];
        locations."/" = {
          proxyPass = "http://adguardhome";
          proxyWebsockets = true;
        };
      };
    };
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/AdGuardHome";
      mode = "0700";
    }
  ];

  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };

  topology.self.services.adguardhome.info = "https://" + adguardhomeDomain;
  services.adguardhome = {
    enable = true;
    mutableSettings = false;
    host = "0.0.0.0";
    port = 3000;
    settings = {
      dns = {
        bind_hosts = [ globals.net.home-lan.vlans.services.hosts.ward-adguardhome.ipv4 ];
        # allowed_clients = [
        # ];
        #trusted_proxies = [];
        ratelimit = 300;
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.google/dns-query"
          "https://doh.mullvad.net/dns-query"
        ];
        bootstrap_dns = [
          "1.1.1.1"
          # FIXME: enable ipv6 "2606:4700:4700::1111"
          "8.8.8.8"
          # FIXME: enable ipv6 "2001:4860:4860::8844"
        ];
        dhcp.enabled = false;
      };
      filtering.rewrites = [
        # Undo the /etc/hosts entry so we don't answer with the internal
        # wireguard address for influxdb
        {
          inherit (globals.services.influxdb) domain;
          answer = globals.domains.me;
          enabled = true;
        }
      ]
      # Use the local mirror-proxy for some services (not necessary, just for speed)
      ++
        map
          (domain: {
            inherit domain;
            answer = globals.net.home-lan.vlans.services.hosts.ward-web-proxy.ipv4;
            enabled = true;
          })
          [
            # FIXME: dont hardcode, filter global service domains by internal state
            # FIXME: new entry here? make new firezone entry too.
            # FIXME: new entry here? make new firezone gateway on ward entry too.
            globals.services.affine.domain
            globals.services.linkwarden.domain
            globals.services.grafana.domain
            globals.services.mealie.domain
            globals.services.immich.domain
            globals.services.influxdb.domain
            globals.services.loki.domain
            globals.services.paperless.domain
            globals.services.esphome.domain
            globals.services.home-assistant.domain
            "fritzbox.${globals.domains.personal}"
          ];
      filters = [
        {
          name = "AdGuard DNS filter";
          url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt";
          enabled = true;
        }
        {
          name = "AdAway Default Blocklist";
          url = "https://adaway.org/hosts.txt";
          enabled = true;
        }
        {
          name = "OISD (Big)";
          url = "https://big.oisd.nl";
          enabled = true;
        }
      ];
    };
  };

  systemd.services.adguardhome.serviceConfig.RestartSec = lib.mkForce "60"; # Retry every minute
}
