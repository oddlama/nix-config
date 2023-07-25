{
  lib,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
in {
  imports = [
    ../../modules/optional/hardware/odroid-n2plus.nix

    ../../modules
    ../../modules/optional/boot-efi.nix
    ../../modules/optional/initrd-ssh.nix
    ../../modules/optional/zfs.nix

    #./esphome.nix
    ./fs.nix
    #./home-assistant.nix
    ./hostapd.nix
    #./mosquitto.nix
    ./kea.nix
    ./net.nix
    #./nginx.nix
    #./zigbee2mqtt.nix
  ];

  meta.wireguard-proxy.sentinel = {};
  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip http authentication
  networking.hosts.${sentinelCfg.meta.wireguard.proxy-sentinel.ipv4} = [sentinelCfg.networking.providedDomains.influxdb];
  meta.telegraf = {
    enable = true;
    influxdb2.domain = sentinelCfg.networking.providedDomains.influxdb;
    influxdb2.organization = "servers";
    influxdb2.bucket = "telegraf";
  };

  # Fails if there are no SMART devices
  services.smartd.enable = lib.mkForce false;
}
