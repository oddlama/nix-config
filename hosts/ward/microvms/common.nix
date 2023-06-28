{nodes, ...}: let
  sentinelCfg = nodes.sentinel.config;
in {
  meta.wireguard-proxy.sentinel = {};
  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${sentinelCfg.meta.wireguard.proxy-sentinel.ipv4} = [sentinelCfg.networking.providedDomains.influxdb];
  meta.telegraf = {
    enable = true;
    influxdb2.domain = sentinelCfg.networking.providedDomains.influxdb;
    influxdb2.organization = "servers";
    influxdb2.bucket = "telegraf";
  };
}
