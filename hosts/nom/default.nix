{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd

    ../../config

    ../../config/hardware/bluetooth.nix
    ../../config/hardware/intel.nix
    ../../config/hardware/nvidia.nix
    ../../config/hardware/physical.nix

    ../../config/dev
    ../../config/graphical
    ../../config/optional/laptop.nix
    ../../config/optional/sound.nix
    ../../config/optional/zfs.nix

    ../../users/malte

    ./fs.nix
    ./net.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "efi";
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];

  console = {
    font = "ter-v28n";
    packages = [ pkgs.terminus_font ];
  };

  # FIXME: fuck optional modules and make this more adjustable via settings
  graphical.gaming.enable = true;

  hardware.nvidia.prime = {
    offload.enable = true;
    offload.enableOffloadCmd = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  services.mullvad-vpn.enable = true;
  environment.persistence."/persist".directories = [
    {
      directory = "/etc/mullvad-vpn";
      user = "root";
      group = "root";
      mode = "0700";
    }
  ];

  topology.self.icon = "devices.laptop";
}
