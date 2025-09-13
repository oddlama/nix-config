{
  config,
  globals,
  ...
}:
{
  imports = [
    ../../config
    ../../config/hardware/hetzner-cloud.nix
    ../../config/optional/zfs.nix

    ./acme.nix
    ./blog.nix
    ./fs.nix
    ./net.nix
    ./firezone.nix
    ./oauth2.nix
    ./plausible.nix
    ./postgresql.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "bios";

  wireguard.proxy-sentinel.firewallRuleForAll.allowedTCPPorts = [
    80
    443
  ];
  wireguard.proxy-sentinel.firewallRuleForAll.allowedUDPPorts = [
    443
  ];

  users.groups.acme.members = [ "nginx" ];
  services.nginx.enable = true;
  services.nginx.recommendedSetup = true;

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4} = [
    globals.services.influxdb.domain
  ];
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
    availableMonitoringNetworks = [ "internet" ];
  };

  services.ente.web = {
    enable = true;
    domains = {
      api = "api.photos.${globals.domains.me}";
      accounts = "accounts.photos.${globals.domains.me}";
      albums = "albums.photos.${globals.domains.me}";
      cast = "cast.photos.${globals.domains.me}";
      photos = "photos.${globals.domains.me}";
    };
  };
}
