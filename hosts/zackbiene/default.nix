{
  lib,
  config,
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    nixos-hardware.common-pc-ssd

    ../common/core
    ../common/zfs.nix

    ../../users/root

    ./fs.nix
    ./net.nix

    ./home-assistant.nix
    ./mosquitto.nix
    ./zigbee2mqtt.nix
    ./esphome.nix
    ./nginx.nix
    ./hostapd.nix
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.initrd.availableKernelModules = [
    "usbhid"
    "usb_storage"
    # Ethernet
    "dwmac_generic"
    "dwmac_meson8b"
    "cfg80211"
    # HDMI
    "snd_soc_meson_g12a_tohdmitx"
    "snd_soc_meson_g12a_toacodec"
    "mdio_mux_meson_g12a"
    "dw_hdmi"
    "meson_vdec"
    "meson_dw_hdmi"
    "meson_drm"
    "meson_rng"
    "drm"
    "display_connector"
  ];
  boot.kernelParams = ["console=ttyAML0,115200n8" "console=tty0"];
  console.earlySetup = true;

  # Fails if there are not SMART devices
  services.smartd.enable = lib.mkForce false;
}
