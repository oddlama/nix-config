{
  config,
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    nixos-hardware.common-cpu-intel
    nixos-hardware.common-pc-ssd

    ../../modules/core

    ../../modules/efi.nix
    ../../modules/zfs.nix

    ../../users/root

    ./fs.nix
    ./net.nix
  ];

  boot = {
    initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci"];
    kernelModules = ["kvm-intel"];
    tmpOnTmpfs = true;
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
  };

  powerManagement.cpuFreqGovernor = "powersave";

  services = {
    fwupd.enable = true;
    smartd.enable = true;
  };

  services.home-assistant = {
    enable = true;
    extraComponents = ["default_config" "met" "zha"];
    openFirewall = true;
    config = {
      default_config = {};
      met = {};
    };
  };
  #networking.firewall.allowedTCPPorts = [1883];
  #services.zigbee2mqtt.enable = true;
  #services.zigbee2mqtt.settings = {
  #  homeassistant = config.services.home-assistant.enable;
  #  permit_join = true;
  #  serial = {
  #    port = "/dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0";
  #  };
  #};
}
