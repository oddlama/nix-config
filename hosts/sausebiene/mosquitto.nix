{ config, ... }:
{
  age.secrets.mosquitto-pw-home-assistant = {
    mode = "440";
    owner = "hass";
    group = "mosquitto";
    generator.script = "alnum";
  };

  services.mosquitto = {
    enable = true;
    persistence = true;
    listeners = [
      {
        acl = [ "pattern readwrite #" ];
        users = {
          # zigbee2mqtt = {
          #   passwordFile = config.age.secrets.mosquitto-pw-zigbee2mqtt.path;
          #   acl = [ "readwrite #" ];
          # };
          home_assistant = {
            passwordFile = config.age.secrets.mosquitto-pw-home-assistant.path;
            acl = [ "readwrite #" ];
          };
        };
        settings.allow_anonymous = false;
      }
    ];
  };

  networking.nftables.firewall.rules = {
    # Allow devices and iot VLANs to access the MQTT server
    access-mqtt = {
      from = [
        "vlan-devices"
        "vlan-iot"
      ];
      to = [ "local" ];
      allowedTCPPorts = [ 1883 ];
    };
  };
}
