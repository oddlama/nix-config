{
  config,
  globals,
  lib,
  ...
}:
let
  localVlans = lib.genAttrs [ "services" "devices" "iot" ] (x: globals.net.home-lan.vlans.${x});
in
{
  networking.hostId = config.repo.secrets.local.networking.hostId;

  globals.monitoring.ping.sausebiene = {
    hostv4 = lib.net.cidr.ip globals.net.home-lan.vlans.services.hosts.sausebiene.cidrv4;
    hostv6 = lib.net.cidr.ip globals.net.home-lan.vlans.services.hosts.sausebiene.cidrv6;
    network = "home-lan.vlans.services";
  };

  boot.initrd.availableKernelModules = [ "8021q" ];
  boot.initrd.systemd.network = {
    enable = true;
    netdevs."30-vlan-services" = {
      netdevConfig = {
        Kind = "vlan";
        Name = "vlan-services";
      };
      vlanConfig.Id = globals.net.home-lan.vlans.services.id;
    };
    networks = {
      "10-lan" = {
        matchConfig.Name = "lan";
        networkConfig.LinkLocalAddressing = "no";
        linkConfig.RequiredForOnline = "carrier";
        vlan = [ "vlan-services" ];
      };
      "30-vlan-services" = {
        address = [
          globals.net.home-lan.vlans.services.hosts.sausebiene.cidrv4
          globals.net.home-lan.vlans.services.hosts.sausebiene.cidrv6
        ];
        gateway = [ globals.net.home-lan.vlans.services.hosts.ward.ipv4 ];
        matchConfig.Name = "vlan-services";
        networkConfig.IPv6PrivacyExtensions = "yes";
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
    }
  );

  systemd.network.networks = {
    "10-lan" = {
      matchConfig.Name = "lan";
      # This interface should only be used from attached vlans.
      # So don't acquire a link local address and only wait for
      # this interface to gain a carrier.
      networkConfig.LinkLocalAddressing = "no";
      linkConfig.RequiredForOnline = "carrier";
      vlan = map (name: "vlan-${name}") (builtins.attrNames localVlans);
    };
  }
  // lib.flip lib.concatMapAttrs localVlans (
    vlanName: vlanCfg: {
      "30-vlan-${vlanName}" = {
        address = [
          vlanCfg.hosts.sausebiene.cidrv4
          vlanCfg.hosts.sausebiene.cidrv6
        ];
        gateway = lib.optionals (vlanName == "services") [ vlanCfg.hosts.ward.ipv4 ];
        matchConfig.Name = "vlan-${vlanName}";
        networkConfig.IPv6PrivacyExtensions = "yes";
        linkConfig.RequiredForOnline = "routable";
      };
    }
  );

  networking.nftables.firewall = {
    zones = {
      untrusted.interfaces = [ "vlan-services" ];
    }
    // lib.flip lib.concatMapAttrs localVlans (
      vlanName: _: {
        "vlan-${vlanName}".interfaces = [ "vlan-${vlanName}" ];
      }
    );

    rules = {
      # Allow devices to be discovered through various protocols
      discovery-protocols = {
        from = [
          "vlan-devices"
          "vlan-iot"
        ];
        to = [ "local" ];
        allowedUDPPorts = [
          1900 # Simple Service Discovery Protocol, UPnP
        ];
        allowedTCPPorts = [
          40000 # UPnP HTTP
        ];
        # HomeKit etc. may use random high-numbered ports.
        # There's probably a better way to handle this
        allowedUDPPortRanges = [
          {
            from = 30000;
            to = 65535;
          }
        ];
      };

      # Allow devices to access some local services
      access-services = {
        from = [
          "vlan-devices"
          "vlan-iot"
        ];
        to = [ "local" ];
        allowedTCPPorts = [
          1883 # MQTT
        ];
      };
    };
  };
}
