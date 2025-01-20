{
  config,
  globals,
  lib,
  ...
}:
{
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  networking.hostId = config.repo.secrets.local.networking.hostId;

  globals.monitoring.ping.ward = {
    hostv4 = lib.net.cidr.ip globals.net.home-lan.vlans.services.hosts.ward.cidrv4;
    hostv6 = lib.net.cidr.ip globals.net.home-lan.vlans.services.hosts.ward.cidrv6;
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
      "10-wan" = {
        address = [ globals.net.home-wan.hosts.ward.cidrv4 ];
        gateway = [ globals.net.home-wan.hosts.fritzbox.ipv4 ];
        matchConfig.Name = "wan";
        networkConfig.IPv6PrivacyExtensions = "yes";
        linkConfig.RequiredForOnline = "routable";
      };
      "10-lan" = {
        matchConfig.Name = "lan";
        # This interface should only be used from attached vlans.
        # So don't acquire a link local address and only wait for
        # this interface to gain a carrier.
        networkConfig.LinkLocalAddressing = "no";
        linkConfig.RequiredForOnline = "carrier";
        vlan = [ "vlan-home" ];
      };
      "30-vlan-home" = {
        address = [
          globals.net.home-lan.vlans.home.hosts.ward.cidrv4
          globals.net.home-lan.vlans.home.hosts.ward.cidrv6
        ];
        matchConfig.Name = "vlan-home";
        networkConfig = {
          IPv4Forwarding = "yes";
          IPv6PrivacyExtensions = "yes";
          MulticastDNS = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  systemd.network.netdevs = lib.flip lib.concatMapAttrs globals.net.home-lan.vlans (
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
        vlan = map (name: "vlan-${name}") (builtins.attrNames globals.net.home-lan.vlans);
      };
      "10-wan" = {
        #DHCP = "yes";
        #dhcpV4Config.UseDNS = false;
        #dhcpV6Config.UseDNS = false;
        #ipv6AcceptRAConfig.UseDNS = false;
        address = [ globals.net.home-wan.hosts.ward.cidrv4 ];
        gateway = [ globals.net.home-wan.hosts.fritzbox.ipv4 ];
        matchConfig.Name = "wan";
        networkConfig.IPv6PrivacyExtensions = "yes";
        # dhcpV6Config.PrefixDelegationHint = "::/64";
        # FIXME: This should not be needed, but for some reason part of networkd
        # isn't seeing the RAs and not triggering DHCPv6. Even though some other
        # part of networkd is properly seeing them and logging accordingly.
        dhcpV6Config.WithoutRA = "solicit";
        linkConfig.RequiredForOnline = "routable";
      };
      # Remaining macvtap interfaces should not be touched.
      "90-macvtap-ignore" = {
        matchConfig.Kind = "macvtap";
        linkConfig.ActivationPolicy = "manual";
        linkConfig.Unmanaged = "yes";
      };
    }
    // lib.flip lib.concatMapAttrs globals.net.home-lan.vlans (
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
            vlanCfg.hosts.ward.cidrv4
            vlanCfg.hosts.ward.cidrv6
          ];
          matchConfig.Name = "me-${vlanName}";
          networkConfig = {
            IPv4Forwarding = "yes";
            IPv6PrivacyExtensions = "yes";
            IPv6SendRA = true;
            IPv6AcceptRA = false;
            # DHCPPrefixDelegation = true;
            MulticastDNS = true;
          };
          # dhcpPrefixDelegationConfig.UplinkInterface = "wan";
          # dhcpPrefixDelegationConfig.Token = "::ff";
          # Announce a static prefix
          ipv6Prefixes = [
            { Prefix = vlanCfg.cidrv6; }
          ];
          # Delegate prefix
          # dhcpPrefixDelegationConfig = {
          #   SubnetId = vlanCfg.id;
          # };
          # Provide a DNS resolver
          # ipv6SendRAConfig = {
          #   Managed = true;
          #   EmitDNS = true;
          # FIXME: this is not the true ipv6 of adguardhome   DNS = globals.net.home-lan.vlans.services.hosts.ward-adguardhome.ipv6;
          # FIXME: todo assign static additional to reservation in kea
          # };
          linkConfig.RequiredForOnline = "routable";
        };
      }
    );

  networking.nftables.firewall = {
    snippets.nnf-icmp.ipv6Types = [
      "mld-listener-query"
      "nd-router-solicit"
    ];

    zones =
      {
        untrusted.interfaces = [ "wan" ];
        proxy-home.interfaces = [ "proxy-home" ];
        adguardhome.ipv4Addresses = [
          globals.net.home-lan.vlans.services.hosts.ward-adguardhome.ipv4
        ];
        adguardhome.ipv6Addresses = [
          globals.net.home-lan.vlans.services.hosts.ward-adguardhome.ipv6
        ];
      }
      // lib.flip lib.concatMapAttrs globals.net.home-lan.vlans (
        vlanName: _: {
          "vlan-${vlanName}".interfaces = [ "me-${vlanName}" ];
        }
      );

    rules = {
      masquerade-internet = {
        from = [
          "vlan-services"
          "vlan-home"
          "vlan-devices"
          "vlan-guests"
        ];
        to = [
          "untrusted"
        ];
        masquerade = true;
        late = true; # Only accept after any rejects have been processed
        verdict = "accept";
      };

      # Allow access to the AdGuardHome DNS server from any VLAN that has internet access
      access-adguardhome-dns = {
        from = [
          "vlan-services"
          "vlan-home"
          "vlan-devices"
          "vlan-guests"
        ];
        to = [ "adguardhome" ];
        verdict = "accept";
      };

      # Allow devices in the home VLAN to talk to any of the services or home devices.
      access-services = {
        from = [
          "vlan-home"
        ];
        to = [
          "vlan-services"
          "vlan-devices"
        ];
        late = true;
        verdict = "accept";
      };

      # Allow the services VLAN to talk to our wireguard server
      services-to-local = {
        from = [ "vlan-services" ];
        to = [ "local" ];
        allowedUDPPorts = [ config.wireguard.proxy-home.server.port ];
      };

      # Forward traffic between wireguard participants
      forward-proxy-home-vpn-traffic = {
        from = [ "proxy-home" ];
        to = [ "proxy-home" ];
        verdict = "accept";
      };
    };
  };

  #wireguard.home.server = {
  #  host = todo # config.networking.fqdn;
  #  port = 51192;
  #  reservedAddresses = ["10.10.0.1/24" "fd00:10::/120"];
  #  openFirewall = true;
  #};

  wireguard.proxy-home.server = {
    host = globals.net.home-lan.vlans.services.hosts.ward.ipv4;
    port = 51444;
    reservedAddresses = [
      globals.net.proxy-home.cidrv4
      globals.net.proxy-home.cidrv6
    ];
    openFirewall = false; # Explicitly opened only for lan
  };
}
