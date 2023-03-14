{
  lib,
  config,
  ...
}: {
  rekey.secrets."mosquitto-pw-zigbee2mqtt.yaml" = {
    file = ./secrets/mosquitto-pw-zigbee2mqtt.yaml.age;
    mode = "440";
    owner = "zigbee2mqtt";
    group = "mosquitto";
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
      mqtt = {
        server = "mqtt://localhost:1883";
        user = "zigbee2mqtt";
        password = "!${config.rekey.secrets."mosquitto-pw-zigbee2mqtt.yaml".path} password";
      };
      frontend = {
        port = 8072;
      };
    };
  };
}
