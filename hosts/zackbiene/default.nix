{
  config,
  lib,
  nodes,
  ...
}: let
  inherit (config.repo.secrets.local) acme;
  sentinelCfg = nodes.sentinel.config;
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

  boot.mode = "efi";
  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;

  security.acme = {
    acceptTerms = true;
    defaults = {
      inherit (acme) email;
      reloadServices = ["nginx"];
    };
  };

  meta.wireguard-proxy.sentinel = {};
  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip http authentication
  networking.hosts.${sentinelCfg.meta.wireguard.proxy-sentinel.ipv4} = [sentinelCfg.networking.providedDomains.influxdb];
  meta.telegraf = {
    enable = true;
    influxdb2 = {
      domain = sentinelCfg.networking.providedDomains.influxdb;
      organization = "servers";
      bucket = "telegraf";
      node = "ward-influxdb";
    };
  };

  # Fails if there are no SMART devices
  services.smartd.enable = lib.mkForce false;
}
