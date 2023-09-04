{config, ...}: {
  age.secrets.mosquitto-pw-zigbee2mqtt = {
    rekeyFile = ./secrets/mosquitto-pw-zigbee2mqtt.age;
    mode = "440";
    owner = "zigbee2mqtt";
    group = "mosquitto";
  };
  age.secrets.mosquitto-pw-home_assistant = {
    rekeyFile = ./secrets/mosquitto-pw-home_assistant.age;
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
            passwordFile = config.age.secrets.mosquitto-pw-zigbee2mqtt.path;
            acl = ["readwrite #"];
          };
          home_assistant = {
            passwordFile = config.age.secrets.mosquitto-pw-home_assistant.path;
            acl = ["readwrite #"];
          };
        };
        settings.allow_anonymous = false;
      }
    ];
  };
}
