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
    ../common/hardware/physical.nix
    ../common/efi.nix
    ../common/initrd-ssh.nix
    ../common/laptop.nix
    # ../common/sound.nix
    ../common/yubikey.nix
    ../common/zfs.nix

    ../../users/myuser

    ./fs.nix
    ./net.nix
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];

  hardware.opengl.enable = true;

  console = {
    font = "ter-v28n";
    packages = with pkgs; [terminus_font];
  };
}
