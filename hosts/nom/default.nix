{
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    nixos-hardware.common-cpu-intel
    nixos-hardware.common-gpu-intel
    nixos-hardware.common-pc-laptop
    nixos-hardware.common-pc-laptop-ssd

    ../../modules/core
    ../../modules/dev
    ../../modules/graphical

    ../../modules/hardware/intel.nix
    ../../modules/efi.nix
    ../../modules/laptop.nix
    ../../modules/sound-pipewire.nix
    ../../modules/yubikey.nix
    ../../modules/zfs.nix

    ../../users/root
    ../../users/myuser

    ./fs.nix
    ./net.nix
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];

  hardware = {
    video.hidpi.enable = true;
    opengl.enable = true;
  };
}
