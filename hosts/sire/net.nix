{
  config,
  globals,
  lib,
  ...
}:
let
  localVlans = lib.genAttrs [ "services" "home" "devices" ] (x: globals.net.home-lan.vlans.${x});
in
{
  networking.hostId = config.repo.secrets.local.networking.hostId;

  globals.monitoring.ping.sire = {
    hostv4 = lib.net.cidr.ip globals.net.home-lan.vlans.services.hosts.sire.cidrv4;
    hostv6 = lib.net.cidr.ip globals.net.home-lan.vlans.services.hosts.sire.cidrv6;
    network = "home-lan.vlans.services";
  };

  boot.initrd.availableKernelModules = [ "8021q" ];
  boot.initrd.systemd.network = {
    enable = true;
    netdevs."30-vlan-home" = {
      netdevConfig = {
        Kind = "vlan";
        Name = "vlan-home";
      };
      vlanConfig.Id = globals.net.home-lan.vlans.home.id;
    };
    networks = {
      "10-lan" = {
        matchConfig.Name = "lan";
        networkConfig.LinkLocalAddressing = "no";
        linkConfig.RequiredForOnline = "carrier";
        vlan = [ "vlan-home" ];
      };
      "30-vlan-home" = {
        address = [
          globals.net.home-lan.vlans.home.hosts.sire.cidrv4
          globals.net.home-lan.vlans.home.hosts.sire.cidrv6
        ];
        gateway = [ globals.net.home-lan.vlans.home.hosts.ward.ipv4 ];
        matchConfig.Name = "vlan-home";
        networkConfig = {
          IPv6PrivacyExtensions = "yes";
          MulticastDNS = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  systemd.network.netdevs = lib.flip lib.concatMapAttrs localVlans (
    vlanName: vlanCfg: {
      # Add an interface for each VLAN
      "30-vlan-${vlanName}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan-${vlanName}";
        };
        vlanConfig.Id = vlanCfg.id;
      };
      # Create a MACVTAP for ourselves too, so that we can communicate with
      # our guests on the same interface.
      "40-me-${vlanName}" = {
        netdevConfig = {
          Name = "me-${vlanName}";
          Kind = "macvlan";
        };
        extraConfig = ''
          [MACVLAN]
          Mode=bridge
        '';
      };
    }
  );

  systemd.network.networks =
    {
      "10-lan" = {
        matchConfig.Name = "lan";
        # This interface should only be used from attached vlans.
        # So don't acquire a link local address and only wait for
        # this interface to gain a carrier.
        networkConfig.LinkLocalAddressing = "no";
        linkConfig.RequiredForOnline = "carrier";
        vlan = map (name: "vlan-${name}") (builtins.attrNames localVlans);
      };
      # Remaining macvtap interfaces should not be touched.
      "90-macvtap-ignore" = {
        matchConfig.Kind = "macvtap";
        linkConfig.ActivationPolicy = "manual";
        linkConfig.Unmanaged = "yes";
      };
    }
    // lib.flip lib.concatMapAttrs localVlans (
      vlanName: vlanCfg: {
        "30-vlan-${vlanName}" = {
          matchConfig.Name = "vlan-${vlanName}";
          # This interface should only be used from attached macvlans.
          # So don't acquire a link local address and only wait for
          # this interface to gain a carrier.
          networkConfig.LinkLocalAddressing = "no";
          networkConfig.MACVLAN = "me-${vlanName}";
          linkConfig.RequiredForOnline = "carrier";
        };
        "40-me-${vlanName}" = {
          address = [
            vlanCfg.hosts.sire.cidrv4
            vlanCfg.hosts.sire.cidrv6
          ];
          gateway = [ vlanCfg.hosts.ward.ipv4 ];
          matchConfig.Name = "me-${vlanName}";
          networkConfig = {
            IPv6PrivacyExtensions = "yes";
            MulticastDNS = true;
          };
          linkConfig.RequiredForOnline = "routable";
        };
      }
    );

  networking.nftables.firewall = {
    zones.untrusted.interfaces = [ "me-services" ];
  };

  # Allow accessing influx
  wireguard.proxy-sentinel.client.via = "sentinel";
}
