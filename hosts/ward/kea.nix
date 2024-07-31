{
  lib,
  globals,
  utils,
  nodes,
  ...
}: let
  inherit (lib) net;
in {
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/kea";
      mode = "0700";
    }
  ];

  # TODO make meta.kea module?
  # TODO reserve by default using assignIps algo?
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
        # XXX: BUG: why does this bind other macvtaps?
        interfaces = ["lan-self"];
        service-sockets-max-retries = -1;
      };
      option-data = [
        {
          name = "domain-name-servers";
          data = globals.net.home-lan.hosts.ward-adguardhome.ipv4;
        }
      ];
      subnet4 = [
        {
          id = 1;
          interface = "lan-self";
          subnet = globals.net.home-lan.cidrv4;
          pools = [
            {pool = "${net.cidr.host 20 globals.net.home-lan.cidrv4} - ${net.cidr.host (-6) globals.net.home-lan.cidrv4}";}
          ];
          option-data = [
            {
              name = "routers";
              data = globals.net.home-lan.hosts.ward.ipv4; # FIXME: how to advertise v6 address also?
            }
          ];
          # FIXME: map this over globals.guests or smth. marker tag for finding: ipv4 192.168.1.1
          reservations = [
            {
              hw-address = nodes.ward-adguardhome.config.lib.microvm.mac;
              ip-address = globals.net.home-lan.hosts.ward-adguardhome.ipv4;
            }
            {
              hw-address = nodes.ward-web-proxy.config.lib.microvm.mac;
              ip-address = globals.net.home-lan.hosts.ward-web-proxy.ipv4;
            }
            {
              hw-address = nodes.sire-samba.config.lib.microvm.mac;
              ip-address = globals.net.home-lan.hosts.sire-samba.ipv4;
            }
            {
              hw-address = globals.macs.wallbox;
              ip-address = globals.net.home-lan.hosts.wallbox.ipv4;
            }
            {
              hw-address = globals.macs.home-assistant;
              ip-address = globals.net.home-lan.hosts.home-assistant-temp.ipv4;
            }
          ];
        }
      ];
    };
  };

  systemd.services.kea-dhcp4-server.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "lan-self"}.device"];
}
