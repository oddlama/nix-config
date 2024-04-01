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
    ./kea.nix
  ];

  topology.self.hardware.image = ../../odroid-h3.png;
  topology.self.hardware.info = "ODROID H3, 64GB RAM";
  topology.self.interfaces.lan.sharesNetworkWith = x: x == "lan-self";

  boot.mode = "efi";
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci" "r8169"];

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${nodes.sentinel.config.wireguard.proxy-sentinel.ipv4} = [nodes.sentinel.config.networking.providedDomains.influxdb];
  meta.telegraf = {
    enable = true;
    influxdb2 = {
      domain = nodes.sentinel.config.networking.providedDomains.influxdb;
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
        ../../modules
        ./guests/common.nix
        ./guests/${guestName}.nix
        {
          node.secretsDir = ./secrets/${guestName};
          networking.nftables.firewall = {
            zones.untrusted.interfaces = [config.guests.${guestName}.networking.mainLinkName];
          };
          topology.self.interfaces.lan.physicalConnections = [
            {
              node = config.node.name;
              interface = "lan-self";
              renderer.reverse = true;
            }
          ];
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
            inherit (inputs.self) nodes;
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
            inherit lib nodes inputs minimal;
          };
        };
    };
  in
    lib.mkIf (!minimal) (
      {}
      // mkMicrovm "adguardhome"
      // mkMicrovm "forgejo"
      // mkMicrovm "kanidm"
      // mkMicrovm "radicale"
      // mkMicrovm "vaultwarden"
    );
}
