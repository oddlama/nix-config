{
  config,
  lib,
  pkgs,
  ...
}:
{
  # There is no reverse proxy here, devices in the LAN access Home Assistant directly.
  # It listens on *:8123 by default, which is configured in the frontend since 2026.8.
  networking.firewall.allowedTCPPorts = [ 8123 ];

  environment.persistence."/persist".directories = [
    {
      directory = config.services.home-assistant.configDir;
      user = "hass";
      group = "hass";
      mode = "0700";
    }
    # Holds the Matter fabric and all commissioned nodes. Losing this means re-pairing every device.
    {
      directory = "/var/lib/private/matterjs-server";
      mode = "0700";
    }
  ];

  services.matterjs-server = {
    enable = true;
    extraArgs = [
      # Matter devices live in the lan, use it to scope link-local addresses
      "--primary-interface=lan"
      # Home Assistant's vendor id, so the fabric isn't shown as a test vendor
      "--vendorid=4939"
    ];
  };

  topology.self.services.home-assistant.info = "http://${config.networking.hostName}.local:8123";
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "esphome"
      "forecast_solar"
      "fritzbox"
      "matter"
      "met"
      "mqtt"
      "music_assistant"
      "ollama"
      "otbr"
      "shelly"
      "thread"
      "wake_word"
      "webostv" # LG WebOS TV
      "whisper"
      "wyoming"
      "zha"
    ];

    customComponents = with pkgs.home-assistant-custom-components; [
      dwd
      moonraker
      waste_collection_schedule
    ];

    customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
      apexcharts-card
      bubble-card
      button-card
      card-mod
      clock-weather-card
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

      zha.zigpy_config.source_routing = true;

      homeassistant = {
        name = "!secret ha_name";
        latitude = "!secret ha_latitude";
        longitude = "!secret ha_longitude";
        elevation = "!secret ha_elevation";
        currency = "EUR";
        time_zone = "Europe/Berlin";
        unit_system = "metric";
        packages.manual = "!include manual.yaml";
      };

      frontend = {
        themes = "!include_dir_merge_named themes";
      };
      "automation ui" = "!include automations.yaml";
      "script ui" = "!include scripts.yaml";
      "scene" = "!include scenes.yaml";

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
    };

    extraPackages =
      python3Packages: with python3Packages; [
        adguardhome
        aioelectricitymaps
        aioipp
        dwdwfsapi
        fritzconnection
        getmac
        gtts
        psycopg2
        pyatv
        pymiele
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
}
