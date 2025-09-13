{
  globals,
  ...
}:
{
  imports = [
    ../../config
    ../../config/hardware/hetzner-cloud.nix
    ../../config/optional/zfs.nix

    ./acme.nix
    ./fs.nix
    ./net.nix
    ./idmail.nix
    ./stalwart-mail.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "bios";

  users.groups.acme.members = [ "nginx" ];
  services.nginx.enable = true;
  services.nginx.recommendedSetup = true;

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${globals.wireguard.proxy-sentinel.hosts.sentinel.ipv4} = [
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
  };
}
