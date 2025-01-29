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
  imports = [ ./hass-modbus/mennekes-amtron-xtra.nix ];

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
      "zha"
    ];

    customComponents = with pkgs.home-assistant-custom-components; [
      (pkgs.home-assistant.python.pkgs.callPackage ./hass-components/ha-bambulab.nix { })
      dwd
      waste_collection_schedule
    ];

    customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
      (builtins.trace "soon upstreamed" (
        pkgs.callPackage ./hass-lovelace/clock-weather-card/package.nix { }
      ))
      (pkgs.callPackage ./hass-lovelace/config-template-card/package.nix { })
      (pkgs.callPackage ./hass-lovelace/hui-element/package.nix { })
      apexcharts-card
      bubble-card
      button-card
      card-mod
      hourly-weather
      lg-webos-remote-control
      mini-graph-card
      multiple-entity-row
      mushroom
      weather-card
      weather-chart-card
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

      influxdb = {
        api_version = 2;
        host = "localhost";
        port = "8086";
        max_retries = 10;
        ssl = false;
        verify_ssl = false;
        token = "!secret influxdb_token";
        organization = "home";
        bucket = "hass";
      };

      waste_collection_schedule = {
        sources = [
          {
            name = "ics";
            args.url = "!secret muell_ics_url";
            calendar_title = "Abfalltermine";
            customize = [
              {
                type = "Restmüll 2-wöchentlich";
                alias = "Restmüll";
              }
              {
                type = "Papiertonne 4-wöchentlich";
                alias = "Papiermüll";
              }
            ];
          }
        ];
      };

      sensor = [
        {
          platform = "waste_collection_schedule";
          name = "restmuell_upcoming";
          value_template = "{{value.types|join(\", \")}}|{{value.daysTo}}|{{value.date.strftime(\"%d.%m.%Y\")}}|{{value.date.strftime(\"%a\")}}";
          types = [ "Restmüll" ];
        }
        {
          platform = "waste_collection_schedule";
          name = "papiermuell_upcoming";
          value_template = "{{value.types|join(\", \")}}|{{value.daysTo}}|{{value.date.strftime(\"%d.%m.%Y\")}}|{{value.date.strftime(\"%a\")}}";
          types = [ "Papiermüll" ];
        }
      ];
    };

    extraPackages =
      python3Packages: with python3Packages; [
        adguardhome
        aioelectricitymaps
        dwdwfsapi
        fritzconnection
        getmac
        gtts
        psycopg2
        pyatv
        pyipp
        pymodbus
        zlib-ng
      ];
  };

  age.secrets."home-assistant-secrets.yaml" = {
    rekeyFile = ./secrets/home-assistant-secrets.yaml.age;
    owner = "hass";
  };

  systemd.services.home-assistant = {
    serviceConfig.LoadCredential = [
      "hass-influxdb-token:${config.age.secrets.hass-influxdb-token.path}"
    ];
    preStart = lib.mkBefore ''
      if [[ -e ${config.services.home-assistant.configDir}/secrets.yaml ]]; then
        rm ${config.services.home-assistant.configDir}/secrets.yaml
      fi

      # Update influxdb token
      # We don't use -i because it would require chown with is a @privileged syscall
      INFLUXDB_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/hass-influxdb-token")" \
        ${lib.getExe pkgs.yq-go} '.influxdb_token = strenv(INFLUXDB_TOKEN)' \
        ${
          config.age.secrets."home-assistant-secrets.yaml".path
        } > ${config.services.home-assistant.configDir}/secrets.yaml

      touch -a ${config.services.home-assistant.configDir}/{automations,scenes,scripts,manual}.yaml
    '';
  };

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
