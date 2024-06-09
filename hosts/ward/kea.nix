{
  lib,
  utils,
  nodes,
  ...
}: let
  inherit (lib) net;
  lanCidrv4 = "192.168.1.0/24";
  dnsIp = net.cidr.host 3 lanCidrv4;
  webProxyIp = net.cidr.host 4 lanCidrv4;
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
          data = dnsIp;
        }
      ];
      subnet4 = [
        {
          id = 1;
          interface = "lan-self";
          subnet = lanCidrv4;
          pools = [
            {pool = "${net.cidr.host 20 lanCidrv4} - ${net.cidr.host (-6) lanCidrv4}";}
          ];
          option-data = [
            {
              name = "routers";
              data = net.cidr.host 1 lanCidrv4; # FIXME: how to advertise v6 address also?
            }
          ];
          reservations = [
            {
              hw-address = nodes.ward-adguardhome.config.lib.microvm.mac;
              ip-address = dnsIp;
            }
            {
              hw-address = nodes.ward-web-proxy.config.lib.microvm.mac;
              ip-address = webProxyIp;
            }
            {
              hw-address = nodes.sire-samba.config.lib.microvm.mac;
              ip-address = net.cidr.host 10 lanCidrv4;
            }
          ];
        }
      ];
    };
  };

  systemd.services.kea-dhcp4-server.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "lan-self"}.device"];
}
