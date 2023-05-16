{
  config,
  lib,
  nodeSecrets,
  ...
}: let
  inherit (config.lib.net) cidr;

  net.lan.ipv4cidr = "192.168.100.1/24";
  net.lan.ipv6cidr = "fd00::1/64";
in {
  networking.hostId = nodeSecrets.networking.hostId;

  boot.initrd.systemd.network = {
    enable = true;
    networks = {inherit (config.systemd.network.networks) "10-wan";};
  };

  # Create a MACVTAP for ourselves too, so that we can communicate with
  # other taps on the same interface.
  systemd.network.netdevs."10-lan-self" = {
    netdevConfig = {
      Name = "lan-self";
      Kind = "macvtap";
    };
    extraConfig = ''
      [MACVTAP]
      Mode=bridge
    '';
  };

  systemd.network.networks = {
    "10-lan" = {
      matchConfig.MACAddress = nodeSecrets.networking.interfaces.lan.mac;
      # This interface should only be used from attached macvtaps.
      # So don't acquire a link local address and only wait for
      # this interface to gain a carrier.
      networkConfig.LinkLocalAddressing = "no";
      linkConfig.RequiredForOnline = "carrier";
      extraConfig = ''
        [Network]
        MACVTAP=lan-self
      '';
    };
    "10-wan" = {
      DHCP = "yes";
      #address = [
      #  "192.168.178.2/24"
      #  "fdee::1/64"
      #];
      #gateway = [
      #];
      matchConfig.MACAddress = nodeSecrets.networking.interfaces.wan.mac;
      networkConfig.IPv6PrivacyExtensions = "yes";
      linkConfig.RequiredForOnline = "routable";
    };
    "20-lan-self" = {
      address = [net.lan.ipv4cidr net.lan.ipv6cidr];
      matchConfig.Name = "lan-self";
      networkConfig = {
        IPForward = "yes";
        IPv6PrivacyExtensions = "yes";
        IPv6SendRA = true;
      };
      # Announce a static prefix
      ipv6Prefixes = [
        {ipv6PrefixConfig.Prefix = cidr.canonicalize net.lan.ipv6cidr;}
      ];
      # Delegate prefix from wan
      #dhcpPrefixDelegationConfig = {
      #  UplinkInterface = "wan";
      #  Announce = true;
      #  SubnetId = "auto";
      #};
      # Provide a DNS resolver
      ipv6SendRAConfig = {
        EmitDNS = true;
        # TODO change to self later
        #DNS = cidr.ip net.lan.ipv6cidr;
        DNS = ["2606:4700:4700::1111" "2001:4860:4860::8888"];
      };
      linkConfig.RequiredForOnline = "routable";
    };
    # Remaining macvtap interfaces should not be touched.
    "90-macvtap-no-ll" = {
      matchConfig.Kind = "macvtap";
      networkConfig.LinkLocalAddressing = "no";
      linkConfig.ActivationPolicy = "manual";
      linkConfig.Unmanaged = "yes";
    };
  };

  networking.nftables.firewall = {
    zones = lib.mkForce {
      lan.interfaces = ["lan-self"];
      wan.interfaces = ["wan"];
    };

    rules = lib.mkForce {
      icmp = {
        # accept ipv6 router solicit and multicast listener discovery query
        extraLines = ["ip6 nexthdr icmpv6 icmpv6 type { mld-listener-query, nd-router-solicit } accept"];
      };

      masquerade-wan = {
        from = ["lan"];
        to = ["wan"];
        masquerade = true;
      };

      outbound = {
        from = ["lan"];
        to = ["lan" "wan"];
        late = true; # Only accept after any rejects have been processed
        verdict = "accept";
      };

      wan-to-local = {
        from = ["wan"];
        to = ["local"];
      };

      lan-to-local = {
        from = ["lan"];
        to = ["local"];

        inherit
          (config.networking.firewall)
          allowedTCPPorts
          allowedUDPPorts
          ;
      };
    };
  };

  # TODO to microvm!
  services.kea = {
    dhcp4 = {
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
          interfaces = ["lan-self"];
          service-sockets-max-retries = -1;
        };
        option-data = [
          {
            name = "domain-name-servers";
            # TODO pihole self
            data = "1.1.1.1, 8.8.8.8";
          }
        ];
        subnet4 = [
          {
            interface = "lan-self";
            subnet = cidr.canonicalize net.lan.ipv4cidr;
            # TODO calculate this automatically, start at 40 or so
            # to have enough for reservations
            pools = [
              {pool = "192.168.100.20 - 192.168.100.250";}
            ];
            option-data = [
              {
                name = "routers";
                data = cidr.ip net.lan.ipv4cidr;
              }
            ];
            # TODO reserve addresses for each VM
            #reservations = [
            #  {
            #    duid = "aa:bb:cc:dd:ee:ff";
            #    ip-address = cidr.ip net.lan.ipv4cidr;
            #  }
            #];
          }
        ];
      };
    };
  };

  systemd.services.kea-dhcp4-server.after = ["sys-subsystem-net-devices-lan.device"];

  #extra.wireguard.vms = {
  #  server = {
  #    enable = true;
  #    host = "192.168.1.231";
  #    port = 51822;
  #    openFirewall = true;
  #  };
  #  addresses = ["10.0.0.1/24"];
  #};
}
