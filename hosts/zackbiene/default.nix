{
  config,
  nixos-hardware,
  pkgs,
  ...
}: {
  imports = [
    nixos-hardware.common-pc-ssd

    ../../modules/core
    ../../modules/efi.nix
    ../../modules/zfs.nix

    ../../users/root

    ./fs.nix
    ./net.nix
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci"];

  powerManagement.cpuFreqGovernor = "powersave";
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
