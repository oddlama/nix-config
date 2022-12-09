{
  config,
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    nixos-hardware.common-cpu-intel
    nixos-hardware.common-gpu-intel
    nixos-hardware.common-pc-laptop
    nixos-hardware.common-pc-laptop-ssd
    ../../core

    ../../hardware/efi.nix
    ../../users/oddlama

    #./state.nix
  ];

  boot = {
    initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
    kernelModules = [];
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    supportedFilesystems = ["zfs"];
    tmpOnTmpfs = true;
  };

  console = {
    font = "ter-v28n";
    keyMap = "de-latin1-nodeadkeys";
    packages = with pkgs; [terminus_font];
  };

  fileSystems = {
    "/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = ["defaults" "noatime" "size=20%" "mode=755"];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/FDA7-5E38";
      fsType = "vfat";
    };
    "/nix" = {
      device = "/dev/disk/by-uuid/4610a590-b6b8-4a8f-82a3-9ec7592911eb";
      fsType = "ext4";
      options = ["defaults" "noatime"];
      neededForBoot = true;
    };
  };

  hardware = {
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
    video.hidpi.enable = lib.mkDefault true;
    opengl.enable = true;
  };

  networking = {
    hostId = "4313abca";
    hostName = "nom";
    wireless.iwd.enable = true;
  };

  powerManagement.cpuFreqGovernor = "performance";

  services = {
    fwupd.enable = true;
    smartd.enable = true;
  };

  systemd.network.networks = {
    wired = {
      DHCP = "yes";
      matchConfig.MACAddress = "1c:83:41:30:ab:9b";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    wireless = {
      DHCP = "yes";
      matchConfig.MACAddress = "60:dd:8e:12:67:bd";
      dhcpV4Config.RouteMetric = 40;
      dhcpV6Config.RouteMetric = 40;
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.root = {
    initialHashedPassword = "$6$EBo/CaxB.dQoq2W8$lo2b5vKgJlLPdGGhEqa08q3Irf1Zd1PcFBCwJOrG8lqjwbABkn1DEhrMh1P3ezwnww2HusUBuZGDSMa4nvSQg1";
    openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm"];
  };
}
