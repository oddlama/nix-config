{
  inputs,
  lib,
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
    ../../config/hardware/bluetooth.nix

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

  # FIXME: fuck optional modules and make this more adjustable via settings
  graphical.gaming.enable = true;
  boot.blacklistedKernelModules = ["nouveau"];
  services.xserver.videoDrivers = lib.mkForce ["nvidia"];

  hardware = {
    nvidia = {
      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
      modesetting.enable = true;
      nvidiaPersistenced = true;
      nvidiaSettings = true;
      open = false;
      powerManagement.enable = false;
    };
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        vaapiVdpau
        nvidia-vaapi-driver
      ];
    };
  };

  topology.self.icon = "devices.laptop";
}
