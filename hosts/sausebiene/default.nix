{
  globals,
  inputs,
  nodes,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    ../../config
    ../../config/hardware/intel.nix
    ../../config/hardware/physical.nix
    ../../config/optional/zfs.nix

    ./fs.nix
    ./net.nix
  ];

  topology.self.hardware.info = "Intel N100, 16GB RAM";

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "efi";

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${nodes.ward-web-proxy.config.wireguard.proxy-home.ipv4} = [
    globals.services.influxdb.domain
  ];
  meta.telegraf = {
    enable = true;
    influxdb2 = {
      inherit (globals.services.influxdb) domain;
      organization = "machines";
      bucket = "telegraf";
      node = "sire-influxdb";
    };
  };
}
