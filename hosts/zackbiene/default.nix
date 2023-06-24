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
    ../common/initrd-ssh.nix
    ../common/zfs.nix
    ../common/bios-boot.nix

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

  # TODO boot.loader.grub.devices = ["/dev/disk/by-id/${config.repo.secrets.local.disk.main}"];
  console.earlySetup = true;

  # Fails if there are no SMART devices
  services.smartd.enable = lib.mkForce false;
}
