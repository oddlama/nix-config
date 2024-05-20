{
  config,
  lib,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  wardWebProxyCfg = nodes.ward-web-proxy.config;
in {
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

  meta.telegraf = lib.mkIf (!config.boot.isContainer) {
    enable = true;
    scrapeSensors = false;
    influxdb2 = {
      domain = sentinelCfg.networking.providedDomains.influxdb;
      organization = "machines";
      bucket = "telegraf";
      node = "sire-influxdb";
    };
  };
}
