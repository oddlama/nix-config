{
  lib,
  config,
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    ../common/core
    ../common/hardware/odroid-n2plus.nix
    #../common/initrd-ssh.nix
    ../common/zfs.nix

    ./fs.nix
    ./net.nix

    #./dnsmasq.nix
    ./esphome.nix
    ./home-assistant.nix
    ./hostapd.nix
    ./mosquitto.nix
    ./nginx.nix
    ./zigbee2mqtt.nix
  ];

  # TODO replace by bios-boot.nix
  # and grub.devices = ... once disko is in use.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  console.earlySetup = true;

  # Fails if there are no SMART devices
  services.smartd.enable = lib.mkForce false;
}
