{
  lib,
  config,
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    nixos-hardware.common-pc-ssd
    ./physical.nix
  ];

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
}
