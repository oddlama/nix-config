{
  config,
  lib,
  ...
}: let
  lanCidrv4 = "192.168.1.0/24";
  lanCidrv6 = "fd10::/64";
in {
  networking.hostId = config.repo.secrets.local.networking.hostId;

  boot.initrd.systemd.network = {
    enable = true;
    networks = {inherit (config.systemd.network.networks) "10-wan";};
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
      address = ["192.168.178.2/24"];
      gateway = ["192.168.178.1"];
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
      # TODO ipv6SendRAConfig = {
      # TODO   EmitDNS = true;
      # TODO   # TODO change to self later
      # TODO   #DNS = lib.net.cidr.host 1 net.lan.ipv6cidr;
      # TODO   DNS = ["2606:4700:4700::1111" "2001:4860:4860::8888"];
      # TODO };
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

  # Allow accessing influx
  wireguard.proxy-sentinel.client.via = "sentinel";

  #wireguard.home.server = {
  #  host = todo # config.networking.fqdn;
  #  port = 51192;
  #  reservedAddresses = ["10.10.0.1/24" "fd00:10::/120"];
  #  openFirewall = true;
  #};
}
