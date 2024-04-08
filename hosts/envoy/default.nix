{nodes, ...}: {
  imports = [
    ../../modules/optional/hardware/hetzner-cloud.nix

    ../../modules
    ../../modules/optional/initrd-ssh.nix
    ../../modules/optional/zfs.nix

    ./acme.nix
    ./fs.nix
    ./net.nix
  ];

  boot.mode = "bios";

  users.groups.acme.members = ["nginx"];
  wireguard.proxy-sentinel.firewallRuleForAll.allowedTCPPorts = [80 443];
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
