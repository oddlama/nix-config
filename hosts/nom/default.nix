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
      device = "rpool/root/nixos";
      fsType = "zfs";
      options = ["zfsutil" "X-mount.mkdir"];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/91ED-0E13";
      fsType = "vfat";
    };
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/1122527a-71d3-4ec7-8d41-65d0c8494b04";}
  ];

  hardware = {
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
    video.hidpi.enable = true;
    opengl.enable = true;
  };

  networking = {
    hostId = "4313abca";
    hostName = "nom";
    wireless.iwd.enable = true;
  };

  powerManagement.cpuFreqGovernor = "powersave";

  services = {
    fwupd.enable = true;
    smartd.enable = true;
  };

  systemd.network.networks = {
    wired = {
      DHCP = "yes";
      matchConfig.MACAddress = "00:00:00:00:00:00";
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    wireless = {
      DHCP = "yes";
      matchConfig.MACAddress = "00:00:00:00:00:00";
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
