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
    ./home-assistant.nix
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
}
