{
  imports = [
    ../users/root

    ./config/boot.nix
    ./config/home-manager.nix
    ./config/impermanence.nix
    ./config/inputrc.nix
    ./config/issue.nix
    ./config/microvms.nix
    ./config/net.nix
    ./config/nftables.nix
    ./config/nix.nix
    ./config/resolved.nix
    ./config/secrets.nix
    ./config/ssh.nix
    ./config/system.nix
    ./config/users.nix
    ./config/xdg.nix

    ./meta/influxdb-retrieve.nix
    ./meta/influxdb.nix
    ./meta/microvms.nix
    ./meta/nginx.nix
    ./meta/oauth2-proxy.nix
    ./meta/promtail.nix
    ./meta/telegraf.nix
    ./meta/wireguard.nix
    ./meta/wireguard-proxy.nix

    ./networking/interface-naming.nix
    ./networking/provided-domains.nix

    ./repo/distributed-config.nix
    ./repo/meta.nix
    ./repo/secrets.nix

    ./security/acme-wildcard.nix

    ./system/deteministic-ids.nix
  ];
}
