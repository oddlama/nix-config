{
  config,
  globals,
  lib,
  ...
}: {
  networking.hostId = config.repo.secrets.local.networking.hostId;

  globals.monitoring.ping.ward = {
    hostv4 = lib.net.cidr.ip globals.net.home-lan.hosts.ward.cidrv4;
    hostv6 = lib.net.cidr.ip globals.net.home-lan.hosts.ward.cidrv6;
    location = "home";
    network = "home-lan";
  };

  boot.initrd.systemd.network = {
    enable = true;
    networks = {
      "10-wan" = {
        address = [globals.net.home-wan.hosts.ward.cidrv4];
        gateway = [globals.net.home-wan.hosts.fritzbox.ipv4];
        matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wan.mac;
        networkConfig.IPv6PrivacyExtensions = "yes";
        linkConfig.RequiredForOnline = "routable";
      };
      "20-lan" = {
        address = [
          globals.net.home-lan.hosts.ward.cidrv4
          globals.net.home-lan.hosts.ward.cidrv6
        ];
        matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
        networkConfig = {
          IPForward = "yes";
          IPv6PrivacyExtensions = "yes";
          MulticastDNS = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  # Create a MACVTAP for ourselves too, so that we can communicate with
  # our guests on the same interface.
  systemd.network.netdevs."10-lan-self" = {
    netdevConfig = {
      Name = "lan-self";
      Kind = "macvlan";
    };
    extraConfig = ''
      [MACVLAN]
      Mode=bridge
    '';
  };

  systemd.network.networks = {
    "10-lan" = {
      matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
      # This interface should only be used from attached macvtaps.
      # So don't acquire a link local address and only wait for
      # this interface to gain a carrier.
      networkConfig.LinkLocalAddressing = "no";
      linkConfig.RequiredForOnline = "carrier";
      extraConfig = ''
        [Network]
        MACVLAN=lan-self
      '';
    };
    "10-wan" = {
      #DHCP = "yes";
      #dhcpV4Config.UseDNS = false;
      #dhcpV6Config.UseDNS = false;
      #ipv6AcceptRAConfig.UseDNS = false;
      address = [globals.net.home-wan.hosts.ward.cidrv4];
      gateway = [globals.net.home-wan.hosts.fritzbox.ipv4];
      matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wan.mac;
      networkConfig.IPv6PrivacyExtensions = "yes";
      dhcpV6Config.PrefixDelegationHint = "::/64";
      # FIXME: This should not be needed, but for some reason part of networkd
      # isn't seeing the RAs and not triggering DHCPv6. Even though some other
      # part of networkd is properly seeing them and logging accordingly.
      dhcpV6Config.WithoutRA = "solicit";
      linkConfig.RequiredForOnline = "routable";
    };
    "20-lan-self" = {
      address = [
        globals.net.home-lan.hosts.ward.cidrv4
        globals.net.home-lan.hosts.ward.cidrv6
      ];
      matchConfig.Name = "lan-self";
      networkConfig = {
        IPForward = "yes";
        IPv6PrivacyExtensions = "yes";
        IPv6SendRA = true;
        IPv6AcceptRA = false;
        DHCPPrefixDelegation = true;
        MulticastDNS = true;
      };
      dhcpPrefixDelegationConfig.UplinkInterface = "wan";
      dhcpPrefixDelegationConfig.Token = "::ff";
      # Announce a static prefix
      ipv6Prefixes = [
        {Prefix = globals.net.home-lan.cidrv6;}
      ];
      # Delegate prefix
      dhcpPrefixDelegationConfig = {
        SubnetId = "22";
      };
      # Provide a DNS resolver
      # ipv6SendRAConfig = {
      #   Managed = true;
      #   EmitDNS = true;
      # FIXME: this is not the true ipv6 of adguardhome   DNS = globals.net.home-lan.hosts.ward-adguardhome.ipv6;
      # FIXME: todo assign static additional to reservation in kea
      # };
      linkConfig.RequiredForOnline = "routable";
    };
    # Remaining macvtap interfaces should not be touched.
    "90-macvtap-ignore" = {
      matchConfig.Kind = "macvtap";
      linkConfig.ActivationPolicy = "manual";
      linkConfig.Unmanaged = "yes";
    };
  };

  networking.nftables.firewall = {
    snippets.nnf-icmp.ipv6Types = ["mld-listener-query" "nd-router-solicit"];

    zones = {
      untrusted.interfaces = ["wan"];
      lan.interfaces = ["lan-self"];
      proxy-home.interfaces = ["proxy-home"];
    };

    rules = {
      masquerade = {
        from = ["lan"];
        to = ["untrusted"];
        masquerade = true;
      };

      outbound = {
        from = ["lan"];
        to = ["lan" "untrusted"];
        late = true; # Only accept after any rejects have been processed
        verdict = "accept";
      };

      lan-to-local = {
        from = ["lan"];
        to = ["local"];

        allowedUDPPorts = [config.wireguard.proxy-home.server.port];
      };

      # Forward traffic between participants
      forward-proxy-home-vpn-traffic = {
        from = ["proxy-home"];
        to = ["proxy-home"];
        verdict = "accept";
      };

      #masquerade-vpn = {
      #  from = ["wg-home"];
      #  to = ["lan"];
      #  masquerade = true;
      #};

      #outbound-vpn = {
      #  from = ["wg-home"];
      #  to = ["lan"];
      #  late = true; # Only accept after any rejects have been processed
      #  verdict = "accept";
      #};
    };
  };

  #wireguard.home.server = {
  #  host = todo # config.networking.fqdn;
  #  port = 51192;
  #  reservedAddresses = ["10.10.0.1/24" "fd00:10::/120"];
  #  openFirewall = true;
  #};

  wireguard.proxy-home.server = {
    host = globals.net.home-lan.hosts.ward.ipv4;
    port = 51444;
    reservedAddresses = [
      globals.net.proxy-home.cidrv4
      globals.net.proxy-home.cidrv6
    ];
    openFirewall = false; # Explicitly opened only for lan
  };
}
