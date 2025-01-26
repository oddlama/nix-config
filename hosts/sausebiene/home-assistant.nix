{
  config,
  globals,
  lib,
  nodes,
  pkgs,
  ...
}:
let
  homeassistantDomain = "home.${globals.domains.personal}";
  fritzboxDomain = "fritzbox.${globals.domains.personal}";
in
{
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

  globals.services.home-assistant.domain = homeassistantDomain;
  # globals.monitoring.http.homeassistant = {
  #   url = "https://${homeasisstantDomain}";
  #   expectedBodyRegex = "homeassistant";
  #   network = "internet";
  # };

  topology.self.services.home-assistant.info = "https://${homeassistantDomain}";
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "esphome"
      "fritzbox"
      "matter"
      "met"
      "mqtt"
      "ollama"
      "radio_browser"
      "soundtouch" # Bose SoundTouch
      "spotify"
      "wake_word"
      "webostv" # LG WebOS TV
      "whisper"
      "wyoming"
    ];

    customComponents = with pkgs.home-assistant-custom-components; [
      (pkgs.home-assistant.python.pkgs.callPackage ./hass-components/ha-bambulab.nix { })
      (philips_airpurifier_coap.overrideAttrs (_: rec {
        version = "0.34.0";
        src = pkgs.fetchFromGitHub {
          owner = "kongo09";
          repo = "philips-airpurifier-coap";
          rev = "v${version}";
          hash = "sha256-jQXQdcgW8IDmjaHjmeyXHcNTXYmknNDw7Flegy6wj2A=";
        };
      }))
    ];

    customLovelaceModules =
      let
        mods = pkgs.home-assistant-custom-lovelace-modules;
      in
      [
        mods.bubble-card
        mods.weather-card
        mods.mini-graph-card
        mods.card-mod
        mods.mushroom
        mods.multiple-entity-row
        mods.button-card
        mods.weather-chart-card
        mods.hourly-weather
      ];

    config = {
      default_config = { };
      http = {
        server_host = [ "0.0.0.0" ];
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = [ nodes.ward-web-proxy.config.wireguard.proxy-home.ipv4 ];
      };

      homeassistant = {
        name = "!secret ha_name";
        latitude = "!secret ha_latitude";
        longitude = "!secret ha_longitude";
        elevation = "!secret ha_elevation";
        currency = "EUR";
        time_zone = "Europe/Berlin";
        unit_system = "metric";
        external_url = "https://${homeassistantDomain}";
        internal_url = "https://${homeassistantDomain}";
        packages.manual = "!include manual.yaml";
      };

      lovelace.mode = "yaml";

      frontend = {
        themes = "!include_dir_merge_named themes";
      };
      "automation ui" = "!include automations.yaml";

      # influxdb = {
      #   api_version = 2;
      #   host = globals.services.influxdb.domain;
      #   port = "443";
      #   max_retries = 10;
      #   ssl = true;
      #   verify_ssl = true;
      #   token = "!secret influxdb_token";
      #   organization = "home";
      #   bucket = "home_assistant";
      # };
    };

    extraPackages =
      python3Packages: with python3Packages; [
        psycopg2
        gtts
        fritzconnection
        adguardhome
        zlib-ng
        pymodbus
        pyipp
        pyatv
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
        ${
          config.age.secrets."home-assistant-secrets.yaml".path
        } > ${config.services.home-assistant.configDir}/secrets.yaml

      touch -a ${config.services.home-assistant.configDir}/{automations,scenes,scripts,manual}.yaml
    '';
  };

  age.secrets.hass-influxdb-token = {
    generator.script = "alnum";
    mode = "440";
    group = "hass";
  };

  # nodes.sire-influxdb = {
  #   # Mirror the original secret on the influx host
  #   age.secrets."hass-influxdb-token-${config.node.name}" = {
  #     inherit (config.age.secrets.hass-influxdb-token) rekeyFile;
  #     mode = "440";
  #     group = "influxdb2";
  #   };
  #
  #   services.influxdb2.provision.organizations.home.auths."home-assistant (${config.node.name})" = {
  #     readBuckets = [ "home_assistant" ];
  #     writeBuckets = [ "home_assistant" ];
  #     tokenFile = nodes.sire-influxdb.config.age.secrets."hass-influxdb-token-${config.node.name}".path;
  #   };
  # };

  # Connect to fritzbox via https proxy (to ensure valid cert)
  networking.hosts.${globals.net.home-lan.vlans.services.hosts.ward-web-proxy.ipv4} = [
    fritzboxDomain
  ];

  networking.hosts.${nodes.ward-adguardhome.config.wireguard.proxy-home.ipv4} = [
    "adguardhome.internal"
  ];

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams."home-assistant" = {
        servers."${config.wireguard.proxy-home.ipv4}:${toString config.services.home-assistant.config.http.server_port}" =
          { };
        extraConfig = ''
          zone home-assistant 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${homeassistantDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://home-assistant";
          proxyWebsockets = true;
        };
        extraConfig = ''
          allow ${globals.net.home-lan.vlans.home.cidrv4};
          allow ${globals.net.home-lan.vlans.home.cidrv6};
          deny all;
        '';
      };
    };
  };
}
