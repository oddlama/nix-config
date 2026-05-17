{ config, globals, ... }:
let
  musicassistantDomain = "music.${globals.domains.personal}";
in
{
  globals.wireguard.proxy-home.hosts.${config.node.name}.firewallRuleForNode.ward-web-proxy.allowedTCPPorts =
    [
      8095
    ];

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/music-assistant";
      mode = "0700";
    }
  ];

  services.music-assistant = {
    enable = true;
    openFirewall = true;
    providers = [
      "airplay"
      "builtin"
      "chromecast"
      "dlna"
      "hass"
      "hass_players"
      "opensubsonic"
      "radiobrowser"
      "sendspin"
      "spotify"
      "spotify_connect"
      "universal_group"
    ];
  };

  globals.services.music-assistant.domain = musicassistantDomain;

  # Connect to music assistant via https proxy (to ensure valid cert)
  networking.hosts.${globals.net.home-lan.vlans.services.hosts.ward-web-proxy.ipv4} = [
    musicassistantDomain
  ];

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams."music-assistant" = {
        servers."${globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4}:8095" = { };
        extraConfig = ''
          zone music-assistant 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${musicassistantDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://music-assistant";
          proxyWebsockets = true;
        };
        extraConfig = ''
          allow ${globals.net.home-lan.vlans.home.cidrv4};
          allow ${globals.net.home-lan.vlans.home.cidrv6};
          allow ${globals.net.home-lan.vlans.devices.cidrv4};
          allow ${globals.net.home-lan.vlans.devices.cidrv6};
          # Self-traffic
          allow ${globals.net.home-lan.vlans.services.hosts.sausebiene.ipv4};
          allow ${globals.net.home-lan.vlans.services.hosts.sausebiene.ipv6};
          # Firezone traffic
          allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv4};
          allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv6};
          deny all;
        '';
      };
    };
  };
}
