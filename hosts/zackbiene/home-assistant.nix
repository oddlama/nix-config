{
  lib,
  config,
  ...
}: {
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "default_config"
      "radio_browser"
      "met"
      "esphome"
      "fritzbox"
      "spotify"
      "zha"
      "mqtt"
    ];
    openFirewall = true;
    config = {
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
      #frontend = {
      #  themes = "!include_dir_merge_named themes";
      #};
      default_config = {};
      met = {};
    };
    extraPackages = python3Packages:
      with python3Packages; [
        psycopg2
        securetar
        libsoundtouch
      ];
  };

  rekey.secrets."home-assistant-secrets.yaml" = {
    file = ./secrets/home-assistant-secrets.yaml.age;
    owner = "hass";
  };

  systemd.services.home-assistant = {
    preStart = lib.mkBefore ''
      ln -sf ${config.rekey.secrets."home-assistant-secrets.yaml".path} ${config.services.home-assistant.configDir}/secrets.yaml
      touch -a ${config.services.home-assistant.configDir}/{automations,scenes,scripts,manual}.yaml
    '';
  };

  # TODO HA and zigbee2mqtt behind nginx please
  #   - auth for zigbee2mqtt frontend
  #   - auth for esphome dashboard
  #   - only allow connections from privileged LAN to HA or from vpn range
}
