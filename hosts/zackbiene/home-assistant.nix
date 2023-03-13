{
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

  # TODO set lat long etc here not manually
  # TODO HA and zigbee2mqtt behind nginx please
  #   - auth for zigbee2mqtt
  #   - auth for esphome dashboard
  #   - only allow connections from privileged LAN to HA or from vpn range
  # TODO use password auth for mosquitto
  services.mosquitto = {
    enable = true;
    persistence = true;
    listeners = [
      {
        acl = ["pattern readwrite #"];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
    ];
  };
  networking.firewall.allowedTCPPorts = [8072];
  services.zigbee2mqtt = {
    enable = true;
    settings = {
      homeassistant = true;
      permit_join = true;
      serial = {
        port = "/dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0";
      };
      frontend = {
        port = 8072;
      };
    };
  };
}
