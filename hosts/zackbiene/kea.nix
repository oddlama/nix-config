{
  lib,
  utils,
  ...
}: let
  inherit (lib) net;
  iotCidrv4 = "10.0.90.0/24"; # FIXME: make all subnet allocations accessible via global.net or smth
in {
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/kea";
      mode = "0700";
    }
  ];

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      lease-database = {
        name = "/var/lib/kea/dhcp4.leases";
        persist = true;
        type = "memfile";
      };
      valid-lifetime = 86400;
      renew-timer = 3600;
      interfaces-config = {
        interfaces = ["wlan1"];
        service-sockets-max-retries = -1;
      };
      option-data = [
        {
          name = "domain-name-servers";
          data = "192.168.1.3"; # FIXME: global (also search for 192.168 and "*Ip =")
        }
      ];
      subnet4 = [
        {
          interface = "wlan1";
          subnet = iotCidrv4;
          pools = [
            {pool = "${net.cidr.host 20 iotCidrv4} - ${net.cidr.host (-6) iotCidrv4}";}
          ];
          option-data = [
            {
              name = "routers";
              data = net.cidr.host 1 iotCidrv4;
            }
          ];
        }
      ];
    };
  };

  systemd.services.kea-dhcp4-server.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "wlan1"}.device"];
}
