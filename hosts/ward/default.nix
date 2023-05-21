{
  config,
  inputs,
  lib,
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    nixos-hardware.common-cpu-intel
    nixos-hardware.common-pc-ssd

    ../common/core
    ../common/hardware/intel.nix
    ../common/hardware/physical.nix
    ../common/initrd-ssh.nix
    ../common/efi.nix
    ../common/zfs.nix

    ../../users/root

    ./fs.nix
    ./net.nix
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci" "r8169"];

  extra.microvms.vms = let
    defineVm = id: {
      inherit id;
      system = "x86_64-linux";
      autostart = true;
      zfs = {
        enable = true;
        pool = "rpool";
      };
    };
  in {
    test = defineVm 11;
    #hi = defineVm 12;
  };

  microvm.vms.test.config = {
    imports = [
      ../common/core
      ../../users/root
    ];

    home-manager.users.root.home.minimal = true;
    rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBXXjI6uB26xOF0DPy/QyLladoGIKfAtofyqPgIkCH/g";
  };
}
