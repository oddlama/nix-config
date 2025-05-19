{
  disabledModules = [
    "services/web-apps/mealie.nix"
  ];
  imports = [
    ./acme-wildcard.nix
    ./backups.nix
    ./deterministic-ids.nix
    ./distributed-config.nix
    ./ente.nix
    ./globals.nix
    ./mealie.nix
    ./meta.nix
    ./nginx-upstream-monitoring.nix
    ./oauth2-proxy.nix
    ./promtail.nix
    ./secrets.nix
    ./telegraf.nix
  ];
}
