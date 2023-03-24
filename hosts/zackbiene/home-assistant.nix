{
  lib,
  config,
  nodeSecrets,
  ...
}: let
  haPort = 8123;
in {
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
    config = {
      http = {
        server_host = ["127.0.0.1"];
        server_port = haPort;
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

  # TODO
  # - auth for zigbee2mqtt frontend
  # - auth for esphome dashboard
  # - only allow connections from privileged LAN to HA or from vpn range

  services.nginx = {
    upstreams."homeassistant" = {
      servers = {"localhost:${toString haPort}" = {};};
      extraConfig = ''
        zone homeassistant 64k;
        keepalive 2;
      '';
    };
    virtualHosts."${nodeSecrets.homeassistant.domain}" = {
      forceSSL = true;
      #enableACME = true;
      sslCertificate = config.rekey.secrets."selfcert.crt".path;
      sslCertificateKey = config.rekey.secrets."selfcert.key".path;
      locations."/" = {
        proxyPass = "http://homeassistant";
        proxyWebsockets = true;
      };
      # TODO dynamic definitions for the "local" network, IPv6
      extraConfig = ''
        allow 192.168.0.0/22;
        deny all;
      '';
    };
  };
}
