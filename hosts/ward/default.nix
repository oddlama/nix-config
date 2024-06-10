{
  config,
  globals,
  inputs,
  lib,
  minimal,
  nodes,
  ...
}: {
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-ssd

    ../../config
    ../../config/hardware/intel.nix
    ../../config/hardware/physical.nix
    ../../config/optional/initrd-ssh.nix
    ../../config/optional/zfs.nix

    ./fs.nix
    ./net.nix
    ./kea.nix
  ];

  topology.self.hardware.image = ../../topology/images/odroid-h3.png;
  topology.self.hardware.info = "O-Droid H3, 64GB RAM";

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "efi";
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci" "r8169"];

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${nodes.ward-web-proxy.config.wireguard.proxy-home.ipv4} = [globals.services.influxdb.domain];
  meta.telegraf = {
    enable = true;
    influxdb2 = {
      inherit (globals.services.influxdb) domain;
      organization = "machines";
      bucket = "telegraf";
      node = "sire-influxdb";
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
        ../../config
        ./guests/common.nix
        ./guests/${guestName}.nix
        {
          node.secretsDir = ./secrets/${guestName};
          networking.nftables.firewall = {
            zones.untrusted.interfaces = [config.guests.${guestName}.networking.mainLinkName];
          };
        }
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
          extraSpecialArgs = {
            inherit (inputs.self) nodes globals;
            inherit (inputs.self.pkgs.x86_64-linux) lib;
            inherit inputs minimal;
          };
        };
    };

    # deadnix: skip
    mkContainer = guestName: {
      ${guestName} =
        mkGuest guestName
        // {
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
      {}
      // mkMicrovm "adguardhome"
      // mkMicrovm "forgejo"
      // mkMicrovm "home-gateway"
      // mkMicrovm "kanidm"
      // mkMicrovm "netbird"
      // mkMicrovm "radicale"
      // mkMicrovm "vaultwarden"
      // mkMicrovm "web-proxy"
    );
}
