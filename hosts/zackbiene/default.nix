{
  lib,
  config,
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    nixos-hardware.common-pc-ssd

    ../../modules/core
    ../../modules/zfs.nix

    ../../users/root

    ./fs.nix
    ./net.nix
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  # Technically generic-extlinux-compatible doesn't support initrd secrets
  # but we are just referring to an existing file in /run using agenix,
  # so it is fine to pretend that it does have proper support.
  boot.loader.supportsInitrdSecrets = true;
  boot.initrd.availableKernelModules = ["usbhid" "usb_storage"]; # "dwmac_meson8b" "meson_dw_hdmi" "meson_drm"];
  boot.kernelParams = ["console=ttyAML0,115200n8" "console=tty0" "loglevel=7"];
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_5_15;
  console.earlySetup = true;

  # Fails if there are not SMART devices
  services.smartd.enable = lib.mkForce false;

  services.home-assistant = {
    enable = true;
    extraComponents = ["default_config" "met"];
    openFirewall = true;
    config = {
      default_config = {};
      met = {};
    };
  };

  #networking.firewall.allowedTCPPorts = [1883];
  #services.zigbee2mqtt.enable = true;
  #services.zigbee2mqtt.settings = {
  #  homeassistant = config.services.home-assistant.enable;
  #  permit_join = true;
  #  serial = {
  #    port = "/dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0";
  #  };
  #};
}
