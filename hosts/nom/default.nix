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

    ../common/core
    ../common/dev
    ../common/graphical

    ../common/hardware/intel.nix
    ../common/efi.nix
    ../common/laptop.nix
    ../common/sound-pipewire.nix
    ../common/yubikey.nix
    ../common/zfs.nix

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
