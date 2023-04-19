{
  lib,
  config,
  nodeSecrets,
  ...
}: {
  services.esphome = {
    enable = true;
    enableUnixSocket = true;
    #allowedDevices = lib.mkForce ["/dev/serial/by-id/usb-Silicon_Labs_CP2102_USB_to_UART_Bridge_Controller_0001-if00-port0"];
    # TODO instead deny the zigbee device
  };

  systemd.services.nginx = {
    serviceConfig.SupplementaryGroups = ["esphome"];
    requires = ["esphome.service"];
  };

  services.nginx = {
    upstreams."esphome" = {
      servers = {"unix:/run/esphome/esphome.sock" = {};};
      extraConfig = ''
        zone esphome 64k;
        keepalive 2;
      '';
    };
    virtualHosts."${nodeSecrets.esphome.domain}" = {
      forceSSL = true;
      #enableACME = true;
      sslCertificate = config.rekey.secrets."selfcert.crt".path;
      sslCertificateKey = config.rekey.secrets."selfcert.key".path;
      locations."/" = {
        proxyPass = "http://esphome";
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
