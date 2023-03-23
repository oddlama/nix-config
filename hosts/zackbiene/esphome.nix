{
  config,
  nodeSecrets,
  ...
}: {
  imports = [../../modules/esphome.nix];

  services.esphome = {
    enable = true;
    enableUnixSocket = true;
    allowedDevices = [
      {
        node = "/dev/serial/by-id/usb-Silicon_Labs_CP2102_USB_to_UART_Bridge_Controller_0001-if00-port0";
        modifier = "rw";
      }
    ];
  };

  systemd.services.nginx.serviceConfig.SupplementaryGroups = ["esphome"];
  systemd.services.nginx.requires = ["esphome.service"];
  services.nginx.upstreams = {
    "esphome" = {
      servers = {"unix:/run/esphome/esphome.sock" = {};};
      extraConfig = ''
        zone esphome 64k;
        keepalive 2;
      '';
    };
  };
  services.nginx.virtualHosts = {
    #"${nodeSecrets.esphome.domain}" = {
    #  forceSSL = true;
    #  enableACME = true;
    "192.168.1.22" = {
      locations."/" = {
        proxyPass = "http://esphome";
        proxyWebsockets = true;
      };
    };
  };
}
