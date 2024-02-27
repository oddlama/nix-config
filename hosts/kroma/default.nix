{
  inputs,
  lib,
  minimal,
  pkgs,
  #nodes,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-hdd
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    ../../modules/optional/hardware/physical.nix
    ../../modules/optional/hardware/nvidia.nix
    ../../modules/optional/hardware/bluetooth.nix

    ../../modules
    ../../modules/optional/initrd-ssh.nix
    ../../modules/optional/dev
    ../../modules/optional/graphical
    ../../modules/optional/laptop.nix
    ../../modules/optional/sound.nix
    ../../modules/optional/zfs.nix

    ../../users/myuser

    ./fs.nix
    ./net.nix
  ];

  boot.mode = "efi";
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
}
// lib.optionalAttrs (!minimal) {
  # TODO goodbye once -sk keys.
  environment.shellInit = ''
    gpg-connect-agent /bye
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
  '';
  networking.extraHosts = "127.0.0.1 modules-cdn.eac-prod.on.epicgames.com";

  #systemd.services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";
  #systemd.services."systemd-resolved".environment.SYSTEMD_LOG_LEVEL = "debug";

  graphical.gaming.enable = true;

  stylix.fonts.sizes = {
    #desktop = 20;
    applications = 10;
    terminal = 20;
    popups = 20;
  };

  nix.settings.trusted-substituters = ["https://ai.cachix.org"];
  nix.settings.trusted-public-keys = ["ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="];

  nixpkgs.config.permittedInsecurePackages = lib.warnIf (pkgs.obsidian.version != "1.5.3") "REMOVE THIS obsidian electron override! in kroma.nix" [
    "electron-25.9.0"
  ];

  # BUG: remove when https://github.com/NixOS/nixpkgs/issues/280826 is merged
  environment.systemPackages = lib.trace "remove pcsclite polkit override https://github.com/NixOS/nixpkgs/issues/280826" [pkgs.pcscliteWithPolkit.out];

  #meta.promtail = {
  #  enable = true;
  #  proxy = "sentinel";
  #};

  ## Connect safely via wireguard to skip authentication
  #networking.hosts.${nodes.sentinel.config.meta.wireguard.proxy-sentinel.ipv4} = [nodes.sentinel.config.networking.providedDomains.influxdb];
  #meta.telegraf = {
  #  enable = true;
  #  influxdb2 = {
  #    domain = nodes.sentinel.config.networking.providedDomains.influxdb;
  #    organization = "machines";
  #    bucket = "telegraf";
  #    node = "sire-influxdb";
  #  };
  #};
}
