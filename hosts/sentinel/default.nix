{
  config,
  globals,
  ...
}: {
  imports = [
    ../../config
    ../../config/hardware/hetzner-cloud.nix
    ../../config/optional/zfs.nix

    ./acme.nix
    ./blog.nix
    ./coturn.nix
    ./fs.nix
    ./net.nix
    ./oauth2.nix
    ./plausible.nix
    ./postgresql.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "bios";

  wireguard.proxy-sentinel.firewallRuleForAll.allowedTCPPorts = [80 443];

  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;
  services.nginx.recommendedSetup = true;

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${config.wireguard.proxy-sentinel.ipv4} = [globals.services.influxdb.domain];
  meta.telegraf = {
    enable = true;
    scrapeSensors = false;
    influxdb2 = {
      inherit (globals.services.influxdb) domain;
      organization = "machines";
      bucket = "telegraf";
      node = "sire-influxdb";
    };

    # This node shall monitor the infrastructure
    availableMonitoringNetworks = ["internet"];
  };
}
