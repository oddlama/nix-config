{
  lib,
  utils,
  ...
}: let
  inherit (lib) net;
  lanCidrv4 = "192.168.1.0/24";
  dnsIp = net.cidr.host 2 lanCidrv4;
in {
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
      valid-lifetime = 4000;
      renew-timer = 1000;
      rebind-timer = 2000;
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
          interface = "lan-self";
          subnet = lanCidrv4;
          pools = [
            {pool = "${net.cidr.host 20 lanCidrv4} - ${net.cidr.host (-6) lanCidrv4}";}
          ];
          option-data = [
            {
              name = "routers";
              data = net.cidr.host 1 lanCidrv4;
            }
          ];
          # TODO reservations = [
          # TODO   {
          # TODO     hw-address = nodes.ward-adguardhome.config.lib.microvm.mac;
          # TODO     ip-address = dnsIp;
          # TODO   }
          # TODO ];
        }
      ];
    };
  };

  systemd.services.kea-dhcp4-server.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "lan-self"}.device"];
}
