{
  imports = [
    ./acme-wildcard.nix
    ./backups.nix
    ./deterministic-ids.nix
    ./distributed-config.nix
    ./globals.nix
    ./meta.nix
    ./nginx-upstream-monitoring.nix
    ./oauth2-proxy.nix
    ./promtail.nix
    ./secrets.nix
    ./telegraf.nix
    ../fz/modules
  ];
}
