{
  config,
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
    ../../modules/optional/initrd-ssh.nix
    ../../modules/optional/zfs.nix

    ./fs.nix
    ./net.nix
  ];

  boot.mode = "efi";
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
      organization = "machines";
      bucket = "telegraf";
      node = "ward-influxdb";
    };
  };

  # TODO track my github stats
  # services.telegraf.extraConfig.inputs.github = {};

  guests = let
    mkGuest = guestName: {enableStorageDataset ? false, ...}: {
      autostart = true;
      zfs."/state" = {
        # TODO make one option out of that? and split into two readonly options automatically?
        pool = "rpool";
        dataset = "local/guests/${guestName}";
      };
      zfs."/persist" = {
        pool = "rpool";
        dataset = "safe/guests/${guestName}";
      };
      zfs."/storage" = lib.mkIf enableStorageDataset {
        pool = "storage";
        dataset = "safe/guests/${guestName}";
      };
      modules = [
        ../../modules
        ./guests/common.nix
        ./guests/${guestName}.nix
        {node.secretsDir = ./secrets/${guestName};}
      ];
    };

    mkMicrovm = guestName: opts: {
      ${guestName} =
        mkGuest guestName opts
        // {
          backend = "microvm";
          microvm = {
            system = "x86_64-linux";
            macvtap = "lan";
            baseMac = config.repo.secrets.local.networking.interfaces.lan.mac;
          };
        };
    };

    # deadnix: skip
    mkContainer = guestName: opts: {
      ${guestName} =
        mkGuest guestName opts
        // {
          backend = "container";
          container.macvlan = "lan";
        };
    };
  in
    lib.mkIf (!minimal) (
      {}
      // mkMicrovm "samba" {enableStorageDataset = true;}
      // mkMicrovm "grafana" {}
      // mkMicrovm "influxdb" {}
      // mkMicrovm "loki" {}
      // mkMicrovm "paperless" {}
      #// mkMicrovm "minecraft"
      #// mkMicrovm "immich"
      #// mkMicrovm "firefly"
      #// mkMicrovm "fasten-health"
    );
}
