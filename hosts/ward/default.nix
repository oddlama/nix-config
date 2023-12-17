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

  #guests.adguardhome = {
  #  backend = "microvm";
  #  microvm = {
  #    system = "x86_64-linux";
  #    macvtapInterface = "lan";
  #  };
  #  autostart = true;
  #  zfs = {
  #    enable = true;
  #    pool = "rpool";
  #  };
  #  modules = [ ./guests/adguardhome.nix ];
  #};

  guests = let
    mkGuest = mainModule: {
      autostart = true;
      zfs = {
        enable = true;
        pool = "rpool";
      };
      modules = [
        ../../modules
        ./guests/common.nix
        ({config, ...}: {node.secretsDir = ./secrets + "/${config.node.name}";})
        mainModule
      ];
    };

    mkMicrovm = system: mainModule:
      mkGuest mainModule
      // {
        backend = "microvm";
        microvm = {
          system = "x86_64-linux";
          macvtapInterface = "lan";
        };
      };

    mkContainer = mainModule:
      mkGuest mainModule
      // {
        backend = "container";
        container.macvlan = "lan";
      };
  in
    lib.mkIf (!minimal) {
      adguardhome = mkContainer ./guests/adguardhome.nix;
      forgejo = mkContainer ./guests/forgejo.nix;
      grafana = mkContainer ./guests/grafana.nix;
      influxdb = mkContainer ./guests/influxdb.nix;
      kanidm = mkContainer ./guests/kanidm.nix;
      loki = mkContainer ./guests/loki.nix;
      paperless = mkContainer ./guests/paperless.nix;
      vaultwarden = mkContainer ./guests/vaultwarden.nix;
    };

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
