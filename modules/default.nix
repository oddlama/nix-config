{
  disabledModules = [
    "services/networking/netbird.nix"
  ];

  imports = [
    ./acme-wildcard.nix
    ./actual.nix
    ./backups.nix
    ./deterministic-ids.nix
    ./distributed-config.nix
    ./globals.nix
    ./meta.nix
    ./netbird-client.nix
    ./nginx-upstream-monitoring.nix
    ./oauth2-proxy.nix
    ./promtail.nix
    ./secrets.nix
    ./telegraf.nix
  ];
}
