{
  globals,
  inputs,
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
    ./malte.nix
    ./net.nix

    ./home-assistant.nix
    ./music-assistant.nix
    ./influxdb.nix
    ./mosquitto.nix
    ./thread.nix
    ./wyoming.nix
  ];

  topology.self.hardware.info = "ODROID H5, Intel i3-N300, 32GB RAM";

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "efi";
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    # The keys can't exist yet when installing, so they are generated on first boot.
    # Enrolling them into the firmware is still done manually.
    autoGenerateKeys.enable = true;
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

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # This host is not in the home network, so reach influxdb through
  # sentinel instead. Connect safely via wireguard to skip authentication.
  networking.hosts.${globals.wireguard.proxy-sentinel.hosts.sentinel.ipv4} = [
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
