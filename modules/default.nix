{
  disabledModules = [
    "services/security/kanidm.nix"
    "services/networking/netbird.nix"
  ];

  imports = [
    ./acme-wildcard.nix
    ./backups.nix
    ./deterministic-ids.nix
    ./distributed-config.nix
    ./globals.nix
    ./kanidm.nix
    ./meta.nix
    ./netbird-client.nix
    ./nginx-upstream-monitoring.nix
    ./oauth2-proxy.nix
    ./promtail.nix
    ./secrets.nix
    ./telegraf.nix
  ];
}
