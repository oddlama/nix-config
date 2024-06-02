{
  config,
  globals,
  lib,
  nodes,
  pkgs,
  ...
}: let
  homeDomain = "home.${config.repo.secrets.global.domains.me}";
  fritzboxDomain = "fritzbox.${config.repo.secrets.global.domains.me}";
in {
  wireguard.proxy-home.firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [
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
        trusted_proxies = [nodes.ward-web-proxy.config.wireguard.proxy-home.ipv4];
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
      backup = {};
      bluetooth = {};
      config = {};
      #cloud = {};
      #conversation = {};
      dhcp = {};
      energy = {};
      history = {};
      homeassistant_alerts = {};
      logbook = {};
      #media_source = {};
      mobile_app = {};
      my = {};
      ssdp = {};
      stream = {};
      sun = {};
      #usb = {};
      webhook = {};
      zeroconf = {};

      ### Components not from default_config

      frontend = {
        #themes = "!include_dir_merge_named themes";
      };

      influxdb = {
        api_version = 2;
        host = globals.services.influxdb.domain;
        port = "443";
        max_retries = 10;
        ssl = true;
        verify_ssl = true;
        token = "!secret influxdb_token";
        organization = "home";
        bucket = "home_assistant";
      };
    };
    extraPackages = python3Packages:
      with python3Packages; [
        psycopg2
        gtts
      ];
  };

  age.secrets."home-assistant-secrets.yaml" = {
    rekeyFile = ./secrets/home-assistant-secrets.yaml.age;
    owner = "hass";
  };

  systemd.services.home-assistant = {
    preStart = lib.mkBefore ''
      if [[ -e ${config.services.home-assistant.configDir}/secrets.yaml ]]; then
        rm ${config.services.home-assistant.configDir}/secrets.yaml
      fi

      # Update influxdb token
      # We don't use -i because it would require chown with is a @privileged syscall
      INFLUXDB_TOKEN="$(cat ${config.age.secrets.hass-influxdb-token.path})" \
        ${lib.getExe pkgs.yq-go} '.influxdb_token = strenv(INFLUXDB_TOKEN)' \
        ${config.age.secrets."home-assistant-secrets.yaml".path} > ${config.services.home-assistant.configDir}/secrets.yaml

      touch -a ${config.services.home-assistant.configDir}/{automations,scenes,scripts,manual}.yaml
    '';
  };

  age.secrets.hass-influxdb-token = {
    generator.script = "alnum";
    mode = "440";
    group = "hass";
  };

  nodes.sire-influxdb = {
    # Mirror the original secret on the influx host
    age.secrets."hass-influxdb-token-${config.node.name}" = {
      inherit (config.age.secrets.hass-influxdb-token) rekeyFile;
      mode = "440";
      group = "influxdb2";
    };

    services.influxdb2.provision.organizations.home.auths."home-assistant (${config.node.name})" = {
      readBuckets = ["home_assistant"];
      writeBuckets = ["home_assistant"];
      tokenFile = nodes.sire-influxdb.config.age.secrets."hass-influxdb-token-${config.node.name}".path;
    };
  };

  # Connect to fritzbox via https proxy (to ensure valid cert)
  networking.hosts."192.168.1.4" = [fritzboxDomain];

  nodes.ward-web-proxy = {
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
        useACMEWildcardHost = true;
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
