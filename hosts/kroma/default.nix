{
  globals,
  inputs,
  lib,
  minimal,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    ../../config

    ../../config/hardware/physical.nix
    ../../config/hardware/nvidia.nix
    ../../config/hardware/bluetooth.nix

    ../../config/dev
    ../../config/graphical
    ../../config/optional/laptop.nix
    ../../config/optional/sound.nix
    ../../config/optional/zfs.nix

    ../../users/myuser

    ./fs.nix
    ./net.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  nixpkgs.config.cudaSupport = true;
  boot.mode = "efi";
  boot.kernelModules = [ "nvidia_uvm" ]; # FIXME: For some reason this doesn't load automatically for me, causing CUDA_ERROR_UNKNOWN (999) issues when trying to cuInit
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
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

  nix.settings.trusted-substituters = [
    "https://ai.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
  ];

  #meta.promtail = {
  #  enable = true;
  #  proxy = "sentinel";
  #};

  ## Connect safely via wireguard to skip authentication
  #networking.hosts.${nodes.sentinel.config.wireguard.proxy-sentinel.ipv4} = [globals.services.influxdb.domain];
  #meta.telegraf = {
  #  enable = true;
  #  influxdb2 = {
  #    domain = globals.services.influxdb.domain;
  #    organization = "machines";
  #    bucket = "telegraf";
  #    node = "sire-influxdb";
  #  };
  #};

  # FIXME: the ui is not directly accessible via environment.systemPackages
  # FIXME: to control it as a user (and to allow SSO) we need to be in the netbird-home group
  services.netbird.ui.enable = true;
  services.netbird.clients.home = {
    port = 51820;
    name = "netbird-home";
    interface = "wt-home";
    autoStart = false;
    openFirewall = true;
    config.ServerSSHAllowed = false;
    environment = rec {
      NB_MANAGEMENT_URL = "https://${globals.services.netbird.domain}";
      NB_ADMIN_URL = NB_MANAGEMENT_URL;
    };
  };
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/netbird-home";
      mode = "0700";
    }
  ];

  programs.nix-ld.enable = true;
  topology.self.icon = "devices.desktop";

  services.flatpak.enable = true;
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  users.deterministicIds.unifi = {
    uid = 968;
    gid = 968;
  };
  services.unifi.enable = true;
}
