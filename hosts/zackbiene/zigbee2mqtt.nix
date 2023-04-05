{
  lib,
  config,
  nodeSecrets,
  ...
}: {
  rekey.secrets."mosquitto-pw-zigbee2mqtt.yaml" = {
    file = ./secrets/mosquitto-pw-zigbee2mqtt.yaml.age;
    mode = "440";
    owner = "zigbee2mqtt";
    group = "mosquitto";
  };

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      advanced.log_level = "warn";
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
      # TODO once 1.30.3 is out
      # frontend.host = "/run/zigbee2mqtt/zigbee2mqtt.sock";
      frontend.port = 8072;
    };
  };

  services.nginx = {
    upstreams."zigbee2mqtt" = {
      servers = {"localhost:8072" = {};};
      extraConfig = ''
        zone zigbee2mqtt 64k;
        keepalive 2;
      '';
    };
    virtualHosts."${nodeSecrets.zigbee2mqtt.domain}" = {
      forceSSL = true;
      #enableACME = true;
      sslCertificate = config.rekey.secrets."selfcert.crt".path;
      sslCertificateKey = config.rekey.secrets."selfcert.key".path;
      locations."/".proxyPass = "http://zigbee2mqtt";
      # TODO dynamic definitions for the "local" network, IPv6
      extraConfig = ''
        allow 192.168.0.0/22;
        deny all;
      '';
    };
  };
}
