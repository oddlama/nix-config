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

  boot = {
    initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
    kernelModules = [];
  };

  console = {
    font = "ter-v28n";
    keyMap = "de-latin1-nodeadkeys";
    packages = with pkgs; [terminus_font];
  };

  environment.systemPackages = with pkgs; [wireguard-tools powertop];

  hardware = {
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
    video.hidpi.enable = true;
    opengl.enable = true;
  };

  powerManagement.cpuFreqGovernor = "powersave";

  services = {
    fwupd.enable = true;
    smartd.enable = true;
    thermald.enable = true;
  };
}
