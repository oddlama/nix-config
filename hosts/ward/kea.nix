{
  lib,
  globals,
  ...
}:
let
  inherit (lib)
    flip
    mapAttrsToList
    net
    ;
in
{
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
        interfaces = map (name: "me-${name}") (builtins.attrNames globals.net.home-lan.vlans);
        service-sockets-max-retries = -1;
      };
      subnet4 = flip mapAttrsToList globals.net.home-lan.vlans (
        vlanName: vlanCfg: {
          inherit (vlanCfg) id;
          interface = "me-${vlanName}";
          subnet = vlanCfg.cidrv4;
          pools = [
            {
              pool = "${net.cidr.host 20 vlanCfg.cidrv4} - ${net.cidr.host (-6) vlanCfg.cidrv4}";
            }
          ];
          option-data =
            [
              {
                name = "routers";
                data = vlanCfg.hosts.ward.ipv4; # FIXME: how to advertise v6 address also?
              }
            ]
            # Advertise DNS server for VLANS that have internet access
            ++
              lib.optional
                (lib.elem vlanName [
                  "services"
                  "home"
                  "devices"
                  "guests"
                ])
                {
                  name = "domain-name-servers";
                  data = globals.net.home-lan.vlans.services.hosts.ward-adguardhome.ipv4;
                };
          reservations = lib.concatLists (
            lib.forEach (builtins.attrValues vlanCfg.hosts) (
              hostCfg:
              lib.optional (hostCfg.mac != null) {
                hw-address = hostCfg.mac;
                ip-address = hostCfg.ipv4;
              }
            )
          );
        }
      );
    };
  };
}
