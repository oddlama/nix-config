{
  nom = {
    pkgs,
    config,
    lib,
    ...
  }: {
    imports = [
      inputs.disko.nixosModules.disko
      {disko.devices = cell.diskoConfigurations.nom;}
      inputs.nixos-hardware.nixosModules.common-cpu-intel
      inputs.nixos-hardware.nixosModules.common-pc-laptop
      inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    ];

    boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = [];
    boot.extraModulePackages = [];

    # ZFS
    networking.hostId = "4313abca";
    boot.supportedFilesystems = ["zfs"];
    boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

    # WWhen using systemd-networkd it's still possible to use this option,
    # but it's recommended to use it in conjunction with explicit per-interface
    # declarations with `networking.interfaces.<interface>.useDHCP`.
    networking.useDHCP = lib.mkDefault false;

    hardware.enableRedistributableFirmware = true;
    hardware.enableAllFirmware = true;
    # high-resolution display
    hardware.video.hidpi.enable = lib.mkDefault true;

    powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  };
}
