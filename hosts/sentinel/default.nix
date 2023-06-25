{
  config,
  lib,
  ...
}: {
  imports = [
    ../common/core
    ../common/hardware/hetzner-cloud.nix
    ../common/bios-boot.nix
    ../common/initrd-ssh.nix
    ../common/zfs.nix

    ./fs.nix
    ./net.nix

    ./acme.nix
    ./oauth2.nix
  ];

  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;

  extra.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${config.extra.wireguard.proxy-sentinel.ipv4} = [config.providedDomains.influxdb];
  extra.telegraf = {
    enable = true;
    influxdb2.url = config.providedDomains.influxdb;
    influxdb2.organization = "servers";
    influxdb2.bucket = "telegraf";
  };
}
