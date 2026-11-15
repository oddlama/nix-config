{ config, ... }:
{
  # Allow devices in the LAN to connect
  networking.firewall.allowedTCPPorts = [ 1883 ];

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
          home_assistant = {
            passwordFile = config.age.secrets.mosquitto-pw-home-assistant.path;
            acl = [ "readwrite #" ];
          };
        };
        settings.allow_anonymous = false;
      }
    ];
  };
}
