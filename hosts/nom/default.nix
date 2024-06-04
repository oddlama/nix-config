{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd

    ../../config

    ../../config/hardware/intel.nix
    ../../config/hardware/physical.nix

    ../../config/dev
    ../../config/graphical
    ../../config/optional/initrd-ssh.nix
    ../../config/optional/laptop.nix
    ../../config/optional/sound.nix
    ../../config/optional/zfs.nix

    ../../users/myuser

    ./fs.nix
    ./net.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "efi";
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];

  console = {
    font = "ter-v28n";
    packages = [pkgs.terminus_font];
  };

  topology.self.icon = "devices.laptop";
}
