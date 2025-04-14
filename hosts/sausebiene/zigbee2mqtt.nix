{
  config,
  globals,
  lib,
  pkgs,
  ...
}:
let
  zigbee2mqttDomain = "zigbee.${globals.domains.personal}";
in
{
  wireguard.proxy-home.firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [
    config.services.zigbee2mqtt.settings.frontend.port
  ];

  globals.services.zigbee2mqtt.domain = zigbee2mqttDomain;
  # globals.monitoring.http.homeassistant = {
  #   url = "https://${homeasisstantDomain}";
  #   expectedBodyRegex = "homeassistant";
  #   network = "internet";
  # };

  services.zigbee2mqtt = {
    enable = true;
    package = pkgs.zigbee2mqtt_2;
    settings = {
      advanced = {
        log_level = "info";
        channel = 25;
      };
      homeassistant = true;
      permit_join = false;
      serial = {
        port = "/dev/serial/by-path/pci-0000:00:14.0-usb-0:5.4:1.0-port0";
        adapter = "zstack";
      };
      mqtt = {
        server = "mqtt://localhost:1883";
        user = "zigbee2mqtt";
        password = "!/run/zigbee2mqtt/secrets.yaml mosquitto-pw";
      };
      frontend.port = 8072;
    };
  };

  systemd.services.zigbee2mqtt = {
    serviceConfig = {
      RuntimeDirectory = "zigbee2mqtt";
      LoadCredential = [
        "mosquitto-pw-zigbee2mqtt:${config.age.secrets.mosquitto-pw-zigbee2mqtt.path}"
      ];
    };
    preStart = lib.mkBefore ''
      # Update mosquitto password
      # We don't use -i because it would require chown with is a @privileged syscall
      MOSQUITTO_PW="$(cat "$CREDENTIALS_DIRECTORY/mosquitto-pw-zigbee2mqtt")" \
        ${lib.getExe pkgs.yq-go} '.mosquitto-pw = strenv(MOSQUITTO_PW)' \
        /dev/null > /run/zigbee2mqtt/secrets.yaml
    '';
  };

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams."zigbee2mqtt" = {
        servers."${config.wireguard.proxy-home.ipv4}:${toString config.services.zigbee2mqtt.settings.frontend.port}" =
          { };
        extraConfig = ''
          zone zigbee2mqtt 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${zigbee2mqttDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://zigbee2mqtt";
          proxyWebsockets = true;
        };
        extraConfig = ''
          allow ${globals.net.home-lan.vlans.home.cidrv4};
          allow ${globals.net.home-lan.vlans.home.cidrv6};
          deny all;
        '';
      };
    };
  };
}
