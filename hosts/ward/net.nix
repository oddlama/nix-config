{
  config,
  lib,
  utils,
  ...
}: let
  lanCidrv4 = "192.168.100.0/24";
  lanCidrv6 = "fd10::/64";
in {
  networking.hostId = config.repo.secrets.local.networking.hostId;

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
      matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
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
      matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wan.mac;
      networkConfig.IPv6PrivacyExtensions = "yes";
      linkConfig.RequiredForOnline = "routable";
    };
    "20-lan-self" = {
      address = [
        (lib.net.cidr.hostCidr 1 lanCidrv4)
        (lib.net.cidr.hostCidr 1 lanCidrv6)
      ];
      matchConfig.Name = "lan-self";
      networkConfig = {
        IPForward = "yes";
        IPv6PrivacyExtensions = "yes";
        IPv6SendRA = true;
        MulticastDNS = true;
      };
      # Announce a static prefix
      ipv6Prefixes = [
        {ipv6PrefixConfig.Prefix = lanCidrv6;}
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
        #DNS = lib.net.cidr.host 1 net.lan.ipv6cidr;
        DNS = ["2606:4700:4700::1111" "2001:4860:4860::8888"];
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

  # TODO mkForce nftables
  networking.nftables.firewall = {
    zones = lib.mkForce {
      untrusted.interfaces = ["wan"];
      lan.interfaces = ["lan-self"];
    };

    rules = lib.mkForce {
      icmp = {
        # accept ipv6 router solicit and multicast listener discovery query
        extraLines = ["ip6 nexthdr icmpv6 icmpv6 type { mld-listener-query, nd-router-solicit } accept"];
      };

      masquerade = {
        from = ["lan"];
        to = ["untrusted"];
        masquerade = true;
      };

      # Rule needed to allow local-vms wireguard traffic
      lan-to-local = {
        from = ["lan"];
        to = ["local"];
      };

      outbound = {
        from = ["lan"];
        to = ["lan" "untrusted"];
        late = true; # Only accept after any rejects have been processed
        verdict = "accept";
      };
    };
  };

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
          # TODO why does this bind other macvtaps?
          interfaces = ["lan-self"];
          service-sockets-max-retries = -1;
        };
        option-data = [
          {
            name = "domain-name-servers";
            # TODO pihole via self
            data = "1.1.1.1, 8.8.8.8";
          }
        ];
        subnet4 = [
          {
            interface = "lan-self";
            subnet = lanCidrv4;
            pools = [
              {pool = "${lib.net.cidr.host 20 lanCidrv4} - ${lib.net.cidr.host (-6) lanCidrv4}";}
            ];
            option-data = [
              {
                name = "routers";
                data = lib.net.cidr.host 1 lanCidrv4;
              }
            ];
          }
        ];
      };
    };
  };

  systemd.services.kea-dhcp4-server.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "lan-self"}.device"];

  meta.microvms.networking = {
    baseMac = config.repo.secrets.local.networking.interfaces.lan.mac;
    macvtapInterface = "lan";
    wireguard.openFirewallRules = ["lan-to-local"];
  };

  # Allow accessing influx
  meta.wireguard.proxy-sentinel.client.via = "sentinel";
}
