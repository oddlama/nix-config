{
  config,
  globals,
  lib,
  ...
}:
{
  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip http authentication
  networking.hosts.${
    if globals.wireguard ? proxy-home then
      globals.wireguard.proxy-home.hosts.ward-web-proxy.ipv4
    else
      globals.wireguard.proxy-sentinel.hosts.sentinel.ipv4
  } =
    [ globals.services.influxdb.domain ];

  meta.telegraf = lib.mkIf (!config.boot.isContainer) {
    enable = true;
    scrapeSensors = false;
    influxdb2 = {
      inherit (globals.services.influxdb) domain;
      organization = "machines";
      bucket = "telegraf";
      node = "sire-influxdb";
    };
  };
}
