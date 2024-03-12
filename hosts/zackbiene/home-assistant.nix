{
  lib,
  config,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  homeDomain = "home.${sentinelCfg.repo.secrets.global.domains.personal}";
in {
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [80];

  environment.persistence."/persist".directories = [
    {
      directory = config.services.home-assistant.configDir;
      user = "hass";
      group = "hass";
      mode = "0700";
    }
  ];

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
      "zha"
      "mqtt"
    ];
    config = {
      http = {
        server_host = ["127.0.0.1"];
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = ["127.0.0.1"];
      };
      homeassistant = {
        name = "!secret ha_name";
        latitude = "!secret ha_latitude";
        longitude = "!secret ha_longitude";
        elevation = "!secret ha_elevation";
        currency = "!secret ha_currency";
        time_zone = "!secret ha_time_zone";
        unit_system = "metric";
        #external_url = "https://";
        packages = {
          manual = "!include manual.yaml";
        };
      };

      #### only selected components from default_config ####

      automation = {};
      backup = {};
      bluetooth = {};
      #cloud = {};
      config = {};
      #conversation = {};
      counter = {};
      dhcp = {};
      energy = {};
      frontend = {
        #themes = "!include_dir_merge_named themes";
      };
      hardware = {};
      history = {};
      homeassistant_alerts = {};
      image_upload = {};
      input_boolean = {};
      input_button = {};
      input_datetime = {};
      input_number = {};
      input_select = {};
      input_text = {};
      logbook = {};
      logger = {};
      map = {};
      #media_source = {};
      mobile_app = {};
      #my = {};
      network = {};
      person = {};
      schedule = {};
      scene = {};
      script = {};
      ssdp = {};
      stream = {};
      sun = {};
      system_health = {};
      tag = {};
      timer = {};
      #usb = {};
      webhook = {};
      zeroconf = {};
      zone = {};
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

  # TODO
  # - auth for zigbee2mqtt frontend
  # - auth for esphome dashboard
  # - only allow connections from privileged LAN to HA or from vpn range

  services.nginx = {
    upstreams.homeassistant = {
      servers."localhost:${toString config.services.home-assistant.config.http.server_port}" = {};
      extraConfig = ''
        zone homeassistant 64k;
        keepalive 2;
      '';
    };
    virtualHosts.${homeDomain} = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://homeassistant";
        proxyWebsockets = true;
      };
      # TODO listenAddresses = ["127.0.0.1" "[::1]"];
      # TODO dynamic definitions for the "local" network, IPv6
      extraConfig = ''
        allow 192.168.0.0/22;
        deny all;
      '';
    };
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams."zackbiene" = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:80" = {};
        extraConfig = ''
          zone zackbiene 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${homeDomain} = {
        # useACMEWildcardHost = true;
        # TODO add aliases
        rejectSSL = true; # TODO TLS SNI pass with `ssl_preread on;`
        locations."/".proxyPass = "http://zackbiene";
      };
    };
  };
}
