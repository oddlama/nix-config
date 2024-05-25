{nodes, ...}: {
  imports = [
    ../../config
    ../../config/hardware/hetzner-cloud.nix
    ../../config/optional/initrd-ssh.nix
    ../../config/optional/zfs.nix

    ./acme.nix
    ./fs.nix
    ./net.nix
    ./maddy.nix
    #./stalwart-mail.nix
  ];

  boot.mode = "bios";

  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;
  services.nginx.recommendedSetup = true;

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${nodes.sentinel.config.wireguard.proxy-sentinel.ipv4} = [nodes.sentinel.config.networking.providedDomains.influxdb];
  meta.telegraf = {
    enable = true;
    scrapeSensors = false;
    influxdb2 = {
      domain = nodes.sentinel.config.networking.providedDomains.influxdb;
      organization = "machines";
      bucket = "telegraf";
      node = "sire-influxdb";
    };
  };
}
