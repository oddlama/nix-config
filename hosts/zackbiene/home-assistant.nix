{
  lib,
  config,
  ...
}: let
  homeDomain = "home.${config.repo.secrets.global.domains.me}";
in {
  wireguard.proxy-home.firewallRuleForNode.ward.allowedTCPPorts = [
    config.services.home-assistant.config.http.server_port
  ];

  environment.persistence."/persist".directories = [
    {
      directory = config.services.home-assistant.configDir;
      user = "hass";
      group = "hass";
      mode = "0700";
    }
  ];

  topology.self.services.home-assistant.info = "https://${homeDomain}";
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "default_config"
      "radio_browser"
      "met"
      "esphome"
      "fritzbox"
      "soundtouch"
      "spotify"
      #"zha"
      "mqtt"
    ];
    config = {
      http = {
        server_host = ["0.0.0.0"];
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = ["127.0.0.1"];
      };

      homeassistant = {
        name = "!secret ha_name";
        latitude = "!secret ha_latitude";
        longitude = "!secret ha_longitude";
        elevation = "!secret ha_elevation";
        currency = "EUR";
        time_zone = "Europe/Berlin";
        unit_system = "metric";
        #external_url = "https://";
        packages = {
          manual = "!include manual.yaml";
        };
      };

      #### only selected components from default_config ####

      assist_pipeline = {};
      bluetooth = {};
      #cloud = {};
      #conversation = {};
      dhcp = {};
      energy = {};
      history = {};
      homeassistant_alerts = {};
      logbook = {};
      map = {};
      #media_source = {};
      mobile_app = {};
      my = {};
      ssdp = {};
      stream = {};
      sun = {};
      #usb = {};
      webhook = {};
      zeroconf = {};

      backup = {};
      config = {};
      frontend = {
        #themes = "!include_dir_merge_named themes";
      };
    };
    extraPackages = python3Packages: with python3Packages; [psycopg2];
  };

  age.secrets."home-assistant-secrets.yaml" = {
    rekeyFile = ./secrets/home-assistant-secrets.yaml.age;
    owner = "hass";
  };

  systemd.services.home-assistant = {
    preStart = lib.mkBefore ''
      ln -sf ${config.age.secrets."home-assistant-secrets.yaml".path} ${config.services.home-assistant.configDir}/secrets.yaml
      touch -a ${config.services.home-assistant.configDir}/{automations,scenes,scripts,manual}.yaml
    '';
  };

  services.nginx = {
    upstreams.homeassistant = {
      extraConfig = ''
        zone homeassistant 64k;
        keepalive 2;
      '';
    };
  };

  nodes.ward = {
    services.nginx = {
      upstreams."home-assistant" = {
        servers."${config.wireguard.proxy-home.ipv4}:${toString config.services.home-assistant.config.http.server_port}" = {};
        extraConfig = ''
          zone home-assistant 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${homeDomain} = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://home-assistant";
          proxyWebsockets = true;
        };
        # FIXME: refer to lan 192.168... and fd10:: via globals
        extraConfig = ''
          allow 192.168.1.0/24;
          allow fd10::/64;
          deny all;
        '';
      };
    };
  };
}
