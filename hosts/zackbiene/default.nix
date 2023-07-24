{lib, ...}: {
  imports = [
    ../../modules/optional/hardware/odroid-n2plus.nix

    ../../modules
    ../../modules/optional/boot-efi.nix
    ../../modules/optional/initrd-ssh.nix
    ../../modules/optional/zfs.nix

    #./dnsmasq.nix
    #./esphome.nix
    ./fs.nix
    #./home-assistant.nix
    #./hostapd.nix
    #./mosquitto.nix
    ./net.nix
    #./nginx.nix
    #./zigbee2mqtt.nix
  ];

  # Fails if there are no SMART devices
  services.smartd.enable = lib.mkForce false;
}
