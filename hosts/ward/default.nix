{
  config,
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    nixos-hardware.common-cpu-intel
    nixos-hardware.common-pc-ssd

    ../common/core
    ../common/hardware/intel.nix
    #../common/initrd-ssh.nix
    ../common/efi.nix
    ../common/zfs.nix

    ../../users/root

    ./fs.nix
    ./net.nix
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci"];

  microvm.vms.agag = {
    flake = self;
    updateFlake = microvm;
  };
  autostart = ["guest"];
}
