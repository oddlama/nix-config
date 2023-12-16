{
  inputs,
  lib,
  nodes,
  minimal,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ../../modules/optional/hardware/intel.nix
    ../../modules/optional/hardware/physical.nix

    ../../modules
    ../../modules/optional/boot-efi.nix
    ../../modules/optional/initrd-ssh.nix
    ../../modules/optional/zfs.nix

    ./fs.nix
    ./net.nix
    ./kea.nix
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci" "r8169"];

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${nodes.sentinel.config.meta.wireguard.proxy-sentinel.ipv4} = [nodes.sentinel.config.networking.providedDomains.influxdb];
  meta.telegraf = {
    enable = true;
    influxdb2 = {
      domain = nodes.sentinel.config.networking.providedDomains.influxdb;
      organization = "servers";
      bucket = "telegraf";
      node = "ward-influxdb";
    };
  };

  # TODO track my github stats
  # services.telegraf.extraConfig.inputs.github = {};

  meta.microvms.commonImports = [
    ../../modules
    ./microvms/common.nix
  ];

  #guests.adguardhome = {
  #  backend = "microvm";
  #  microvm = {
  #    system = "x86_64-linux";
  #    autostart = true;
  #  };
  #  zfs = {
  #    enable = true;
  #    pool = "rpool";
  #  };
  #  modules = [ ./guests/adguardhome.nix ];
  #};

  guests = let
    mkMicrovm = system: module: {
      backend = "microvm";
      microvm = {
        system = "x86_64-linux";
        autostart = true;
      };
      zfs = {
        enable = true;
        pool = "rpool";
      };
      modules = [
        ../../modules
        module
      ];
    };
  in {
    adguardhome = mkMicrovm "x86_64-linux" ./guests/adguardhome.nix;
  };

  meta.microvms.vms = let
    defaultConfig = name: {
      system = "x86_64-linux";
      autostart = true;
      zfs = {
        enable = true;
        pool = "rpool";
      };
      modules = [
        # XXX: this could be interpolated in-place but statix has a bug https://github.com/nerdypepper/statix/issues/75
        (./microvms + "/${name}.nix")
        {node.secretsDir = ./secrets + "/${name}";}
      ];
    };
  in
    lib.mkIf (!minimal) (
      lib.genAttrs [
        "adguardhome"
        "forgejo"
        "grafana"
        "influxdb"
        "kanidm"
        "loki"
        "paperless"
        "vaultwarden"
      ]
      defaultConfig
    );

  #ddclient = defineVm;
  #samba+wsdd = defineVm;
  #fasten-health = defineVm;
  #immich = defineVm;
  #paperless = defineVm;
  #radicale = defineVm;
  #minecraft = defineVm;
  #firefly

  #maddy = defineVm;
  #anonaddy = defineVm;

  #automatic1111 = defineVm;
  #invokeai = defineVm;
}
