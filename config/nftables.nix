{
  config,
  lib,
  ...
}:
{
  networking.nftables = {
    stopRuleset = lib.mkDefault ''
      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;
          ct state invalid drop
          ct state {established, related} accept

          iifname lo accept
          meta l4proto ipv6-icmp accept
          meta l4proto icmp accept
          ip protocol igmp accept
          tcp dport ${toString (lib.head config.services.openssh.ports)} accept
        }
        chain forward {
          type filter hook forward priority filter; policy drop;
        }
        chain output {
          type filter hook output priority filter; policy accept;
        }
      }
    '';

    firewall = {
      enable = true;
      localZoneName = "local";
      snippets = {
        nnf-common.enable = false;
        nnf-conntrack.enable = true;
        nnf-drop.enable = true;
        nnf-loopback.enable = true;
        nnf-ssh.enable = true;
      };

      rules.untrusted-to-local = {
        from = [ "untrusted" ];
        to = [ "local" ];

        inherit (config.networking.firewall)
          allowedTCPPorts
          allowedTCPPortRanges
          allowedUDPPorts
          allowedUDPPortRanges
          ;
      };

      rules.icmp-and-igmp = {
        after = [
          "ct"
          "ssh"
        ];
        from = "all";
        to = [ "local" ];
        extraLines = [
          "meta l4proto ipv6-icmp accept"
          "meta l4proto icmp accept"
          "ip protocol igmp accept"
        ];
      };
    };
  };
}
