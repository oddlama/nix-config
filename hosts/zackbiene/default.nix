{
  config,
  lib,
  nodes,
  ...
}: let
  inherit (config.repo.secrets.local) acme;
  sentinelCfg = nodes.sentinel.config;
  wardWebProxyCfg = nodes.ward-web-proxy.config;
in {
  imports = [
    ../../modules/optional/hardware/odroid-n2plus.nix

    ../../modules
    ../../modules/optional/initrd-ssh.nix
    ../../modules/optional/zfs.nix

    #./esphome.nix
    ./fs.nix
    ./home-assistant.nix
    ./hostapd.nix
    #./mosquitto.nix
    ./kea.nix
    ./net.nix
    #./zigbee2mqtt.nix
  ];

  topology.self.name = "🥔  zackbiene"; # yes this is 2x U+2009, don't ask (satori 🤬).
  topology.self.hardware.image = ../../topology/images/odroid-n2plus.png;
  topology.self.hardware.info = "O-Droid N2+";

  boot.mode = "efi";
  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;
  services.nginx.recommendedSetup = true;

  security.acme = {
    acceptTerms = true;
    defaults = {
      inherit (acme) email;
      reloadServices = ["nginx"];
    };
  };

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip http authentication
  networking.hosts.${
    if config.wireguard ? proxy-home
    then wardWebProxyCfg.wireguard.proxy-home.ipv4
    else sentinelCfg.wireguard.proxy-sentinel.ipv4
  } = [sentinelCfg.networking.providedDomains.influxdb];

  meta.telegraf = {
    enable = true;
    influxdb2 = {
      domain = sentinelCfg.networking.providedDomains.influxdb;
      organization = "machines";
      bucket = "telegraf";
      node = "sire-influxdb";
    };
  };

  # Fails if there are no SMART devices
  services.smartd.enable = lib.mkForce false;
}
