{
  config,
  globals,
  lib,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  wardWebProxyCfg = nodes.ward-web-proxy.config;
in {
  imports = [
    ../../config
    ../../config/hardware/odroid-n2plus.nix
    ../../config/hardware/physical.nix
    ../../config/optional/initrd-ssh.nix
    ../../config/optional/zfs.nix

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

  nixpkgs.hostPlatform = "aarch64-linux";
  boot.mode = "efi";

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip http authentication
  networking.hosts.${
    if config.wireguard ? proxy-home
    then wardWebProxyCfg.wireguard.proxy-home.ipv4
    else sentinelCfg.wireguard.proxy-sentinel.ipv4
  } = [globals.services.influxdb.domain];

  meta.telegraf = {
    enable = true;
    influxdb2 = {
      inherit (globals.services.influxdb) domain;
      organization = "machines";
      bucket = "telegraf";
      node = "sire-influxdb";
    };
  };

  # Fails if there are no SMART devices
  services.smartd.enable = lib.mkForce false;
}
