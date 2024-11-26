{
  config,
  globals,
  inputs,
  lib,
  nodes,
  minimal,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    ../../config
    ../../config/hardware/intel.nix
    ../../config/hardware/physical.nix
    ../../config/optional/zfs.nix

    ./fs.nix
    ./net.nix
  ];

  topology.self.hardware.info = "AMD Ryzen Threadripper 1950X, 96GB RAM";

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "efi";
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "e1000e"
    "alx"
  ];
  systemd.units."dev-tpmrm0.device".enable = false; # https://github.com/systemd/systemd/issues/33412

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${nodes.sentinel.config.wireguard.proxy-sentinel.ipv4} = [
    globals.services.influxdb.domain
  ];
  meta.telegraf = {
    enable = true;
    influxdb2 = {
      inherit (globals.services.influxdb) domain;
      organization = "machines";
      bucket = "telegraf";
      node = "sire-influxdb";
    };
  };

  guests =
    let
      mkGuest =
        guestName:
        {
          enableStorageDataset ? false,
          enableBunkerDataset ? false,
          enablePaperlessDataset ? false,
          ...
        }:
        {
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
          zfs."/bunker" = lib.mkIf enableBunkerDataset {
            pool = "storage";
            dataset = "bunker/guests/${guestName}";
          };
          zfs."/paperless" = lib.mkIf enablePaperlessDataset {
            pool = "storage";
            dataset = "bunker/paperless";
          };
          modules = [
            ../../config
            ./guests/common.nix
            ./guests/${guestName}.nix
            {
              node.secretsDir = ./secrets/${guestName};
              networking.nftables.firewall = {
                zones.untrusted.interfaces = [ config.guests.${guestName}.networking.mainLinkName ];
              };
            }
          ];
        };

      mkMicrovm = guestName: opts: {
        ${guestName} = mkGuest guestName opts // {
          backend = "microvm";
          microvm = {
            system = "x86_64-linux";
            macvtap = "lan";
            baseMac = config.repo.secrets.local.networking.interfaces.lan.mac;
          };
          extraSpecialArgs = {
            inherit (inputs.self) nodes globals;
            inherit (inputs.self.pkgs.x86_64-linux) lib;
            inherit inputs minimal;
          };
        };
      };

      # deadnix: skip
      mkContainer = guestName: opts: {
        ${guestName} = mkGuest guestName opts // {
          backend = "container";
          container.macvlan = "lan";
          extraSpecialArgs = {
            inherit (inputs.self) nodes globals;
            inherit (inputs.self.pkgs.x86_64-linux) lib;
            inherit inputs minimal;
          };
        };
      };
    in
    lib.mkIf (!minimal) (
      { }
      // mkMicrovm "actual" { }
      // mkMicrovm "samba" {
        enableStorageDataset = true;
        enableBunkerDataset = true;
        enablePaperlessDataset = true;
      }
      // mkMicrovm "grafana" { }
      // mkMicrovm "influxdb" { }
      // mkMicrovm "loki" { }
      // mkMicrovm "paperless" {
        enablePaperlessDataset = true;
      }
      // mkMicrovm "immich" {
        enableStorageDataset = true;
      }
      // mkMicrovm "ai" { }
      // mkMicrovm "minecraft" { }
      #// mkMicrovm "firefly" {}
      #// mkMicrovm "fasten-health" {}
    );
}
