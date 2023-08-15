{
  config,
  lib,
  ...
}: {
  imports = [
    ../../modules/optional/hardware/hetzner-cloud.nix

    ../../modules
    ../../modules/optional/boot-bios.nix
    ../../modules/optional/initrd-ssh.nix
    ../../modules/optional/zfs.nix

    ./acme.nix
    ./fs.nix
    ./net.nix
    ./oauth2.nix
  ];

  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${config.meta.wireguard.proxy-sentinel.ipv4} = [config.networking.providedDomains.influxdb];
  meta.telegraf = {
    enable = true;
    scrapeSensors = false;
    influxdb2 = {
      domain = config.networking.providedDomains.influxdb;
      organization = "servers";
      bucket = "telegraf";
      node = "ward-influxdb";
    };
  };
}
