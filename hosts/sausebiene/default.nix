{
  globals,
  inputs,
  nodes,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.lanzaboote.nixosModules.lanzaboote

    ../../config
    ../../config/hardware/intel.nix
    ../../config/hardware/physical.nix
    ../../config/optional/zfs.nix

    ./fs.nix
    ./net.nix

    ./esphome.nix
    ./home-assistant.nix
    ./influxdb.nix
    ./mosquitto.nix
    ./wyoming.nix
  ];

  topology.self.hardware.info = "Intel N100, 16GB RAM";

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "efi";
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  boot.initrd.availableKernelModules = [
    "r8169"
  ];
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
  };

  environment.systemPackages = [ pkgs.sbctl ];
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/sbctl";
      mode = "0700";
    }
  ];

  systemd.tmpfiles.settings."01-var-lib-private"."/var/lib/private".d = {
    user = "root";
    mode = "0700";
  };

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
