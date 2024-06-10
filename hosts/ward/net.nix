{
  config,
  globals,
  ...
}: {
  networking.hostId = config.repo.secrets.local.networking.hostId;

  globals.net = {
    home-wan = {
      cidrv4 = "192.168.178.0/24";
      hosts.fritzbox.id = 1;
      hosts.ward.id = 2;
    };

    home-lan = {
      cidrv4 = "192.168.1.0/24";
      cidrv6 = "fd10::/64";
      hosts.ward.id = 1;
      hosts.sire.id = 2;
      hosts.ward-adguardhome.id = 3;
      hosts.ward-web-proxy.id = 4;
      hosts.sire-samba.id = 10;
    };

    proxy-home = {
      cidrv4 = "10.44.0.0/24";
      cidrv6 = "fd00:44::/120";
    };
  };

  boot.initrd.systemd.network = {
    enable = true;
    networks = {
      inherit (config.systemd.network.networks) "10-wan";
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
      # Announce a static prefix
      ipv6Prefixes = [
        {ipv6PrefixConfig.Prefix = globals.net.home-lan.cidrv6;}
      ];
      # Delegate prefix
      dhcpPrefixDelegationConfig = {
        SubnetId = "22";
      };
      # Provide a DNS resolver
      ipv6SendRAConfig = {
        EmitDNS = true;
        DNS = globals.net.home-lan.hosts.ward-adguardhome.ipv4;
      };
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
