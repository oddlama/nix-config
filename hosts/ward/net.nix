{
  config,
  globals,
  lib,
  ...
}:
{
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
  networking.hostId = config.repo.secrets.local.networking.hostId;

  globals.monitoring.ping.ward = {
    hostv4 = lib.net.cidr.ip globals.net.home-lan.vlans.services.hosts.ward.cidrv4;
    hostv6 = lib.net.cidr.ip globals.net.home-lan.vlans.services.hosts.ward.cidrv6;
    network = "home-lan.vlans.services";
  };

  # Reflect mDNS packets between our networks
  services.avahi.reflector = true;

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

  systemd.network.networks = {
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

  networking.nftables = {
    firewall = {
      zones = {
        untrusted.interfaces = [ "wan" ];
        proxy-home.interfaces = [ "proxy-home" ];
        firezone.interfaces = [ "tun-firezone" ];
        adguardhome.ipv4Addresses = [ globals.net.home-lan.vlans.services.hosts.ward-adguardhome.ipv4 ];
        adguardhome.ipv6Addresses = [ globals.net.home-lan.vlans.services.hosts.ward-adguardhome.ipv6 ];
        web-proxy.ipv4Addresses = [ globals.net.home-lan.vlans.services.hosts.ward-web-proxy.ipv4 ];
        web-proxy.ipv6Addresses = [ globals.net.home-lan.vlans.services.hosts.ward-web-proxy.ipv6 ];
        samba.ipv4Addresses = [ globals.net.home-lan.vlans.services.hosts.sire-samba.ipv4 ];
        samba.ipv6Addresses = [ globals.net.home-lan.vlans.services.hosts.sire-samba.ipv6 ];
        scanner-ads-4300n.ipv4Addresses = [
          globals.net.home-lan.vlans.devices.hosts.scanner-ads-4300n.ipv4
        ];
        scanner-ads-4300n.ipv6Addresses = [
          globals.net.home-lan.vlans.devices.hosts.scanner-ads-4300n.ipv6
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
          to = [ "untrusted" ];
          # masquerade = true; NOTE: custom rule below for ip4 + ip6
          late = true; # Only accept after any rejects have been processed
          verdict = "accept";
        };

        # masquerade firezone traffic
        masquerade-firezone = {
          from = [ "firezone" ];
          to = [ "vlan-services" ];
          # masquerade = true; NOTE: custom rule below for ip4 + ip6
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

        # Allow access to the web proxy from the devices VLAN
        access-web-proxy = {
          from = [
            "vlan-devices"
          ];
          to = [ "web-proxy" ];
          allowedTCPPorts = [
            80
            443
          ];
          allowedUDPPorts = [ 443 ];
          verdict = "accept";
        };

        # Allow the scanner to access samba via SFTP
        access-samba-sftp = {
          from = [ "scanner-ads-4300n" ];
          to = [ "samba" ];
          allowedTCPPorts = [ 22 ];
        };

        # Allow devices in the home VLAN to talk to any of the services or home devices.
        access-services = {
          from = [ "vlan-home" ];
          to = [
            "vlan-services"
            "vlan-devices"
            "vlan-iot"
          ];
          late = true;
          verdict = "accept";
        };

        # Allow the services VLAN to talk to our wireguard server
        services-to-local = {
          from = [ "vlan-services" ];
          to = [ "local" ];
          allowedUDPPorts = [ globals.wireguard.proxy-home.port ];
        };

        # Forward traffic between wireguard participants
        forward-proxy-home-vpn-traffic = {
          from = [ "proxy-home" ];
          to = [ "proxy-home" ];
          verdict = "accept";
        };

        # forward firezone traffic
        forward-incoming-firezone-traffic = {
          from = [ "firezone" ];
          to = [ "vlan-services" ];
          verdict = "accept";
        };

        # FIXME: is this needed? conntrack should take care of it and we want to masquerade anyway
        forward-outgoing-firezone-traffic = {
          from = [ "vlan-services" ];
          to = [ "firezone" ];
          verdict = "accept";
        };
      };
    };

    chains.postrouting = {
      masquerade-firezone = {
        after = [ "hook" ];
        late = true;
        rules =
          lib.forEach
            [
              "firezone"
            ]
            (
              zone:
              lib.concatStringsSep " " [
                "meta protocol { ip, ip6 }"
                (lib.head config.networking.nftables.firewall.zones.${zone}.ingressExpression)
                (lib.head config.networking.nftables.firewall.zones.vlan-services.egressExpression)
                "masquerade random"
              ]
            );
      };

      masquerade-internet = {
        after = [ "hook" ];
        late = true;
        rules =
          lib.forEach
            [
              "vlan-services"
              "vlan-home"
              "vlan-devices"
              "vlan-guests"
            ]
            (
              zone:
              lib.concatStringsSep " " [
                "meta protocol { ip, ip6 }"
                (lib.head config.networking.nftables.firewall.zones.${zone}.ingressExpression)
                (lib.head config.networking.nftables.firewall.zones.untrusted.egressExpression)
                "masquerade random"
              ]
            );
      };
    };
  };

  globals.wireguard.proxy-home = {
    openFirewall = false; # Explicitly opened only for lan
    hosts.${config.node.name}.server = true;
  };
}
