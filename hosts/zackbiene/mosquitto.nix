{
  lib,
  config,
  ...
}: {
  rekey.secrets.mosquitto-pw-zigbee2mqtt = {
    file = ./mosquitto-pw-zigbee2mqtt.age;
    mode = "440";
    owner = "zigbee2mqtt";
    group = "mosquitto";
  };
  rekey.secrets.mosquitto-pw-home_assistant = {
    file = ./mosquitto-pw-home_assistant.age;
    mode = "440";
    owner = "hass";
    group = "mosquitto";
  };

  services.mosquitto = {
    enable = true;
    persistence = true;
    listeners = [
      {
        acl = ["pattern readwrite #"];
        users = {
          zigbee2mqtt = {
            passwordFile = config.rekey.secrets.mosquitto-pw-zigbee2mqtt.path;
            acl = ["readwrite #"];
          };
          home_assistant = {
            passwordFile = config.rekey.secrets.mosquitto-pw-home_assistant.path;
            acl = ["readwrite #"];
          };
        };
        settings.allow_anonymous = false;
      }
    ];
  };
}
