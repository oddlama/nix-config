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

  guests = let
    mkGuest = guestName: {
      autostart = true;
      zfs."/state" = {
        pool = "rpool";
        dataset = "local/guests/${guestName}";
      };
      zfs."/persist" = {
        pool = "rpool";
        dataset = "safe/guests/${guestName}";
      };
      modules = [
        ../../modules
        ./guests/common.nix
        ./guests/${guestName}.nix
        {node.secretsDir = ./secrets/${guestName};}
      ];
    };

    mkMicrovm = guestName: {
      ${guestName} =
        mkGuest guestName
        // {
          backend = "microvm";
          microvm = {
            system = "x86_64-linux";
            macvtap = "lan";
            baseMac = config.repo.secrets.local.networking.interfaces.lan.mac;
          };
        };
    };

    mkContainer = guestName: {
      ${guestName} =
        mkGuest guestName
        // {
          backend = "container";
          container.macvlan = "lan";
        };
    };
  in
    lib.mkIf (!minimal) (
      {}
      // mkMicrovm "adguardhome"
      // mkContainer "forgejo"
      // mkContainer "grafana"
      // mkContainer "influxdb"
      // mkContainer "kanidm"
      // mkContainer "loki"
      // mkContainer "paperless"
      // mkContainer "vaultwarden"
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
