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
    ../../../common/core

    ../../../../users/root
  ];

  home-manager.users.root.home.minimal = true;

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
