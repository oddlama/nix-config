{
  config,
  inputs,
  lib,
  microvm,
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    microvm.microvm

    ../../../common/core

    ../../../../users/root
  ];

  systemd.network.networks = {
    "10-wan" = {
      # TODO
      matchConfig.Name = "en*";
      DHCP = "yes";
      networkConfig.IPv6PrivacyExtensions = "kernel";
      dhcpV4Config.RouteMetric = 20;
      dhcpV6Config.RouteMetric = 20;
    };
  };
}
