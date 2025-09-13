{
  config,
  globals,
  inputs,
  lib,
  minimal,
  nodes,
  ...
}:
let
  # FIXME: dont hardcode, filter global service domains by internal state
  # FIXME: new entry here? make new adguardhome entry too.
  # FIXME: new entry here? make new firezone entry too.
  homeDomains = [
    globals.services.grafana.domain
    # TODO: allow multiple domains per global service.
    "accounts.photos.${globals.domains.me}"
    "albums.photos.${globals.domains.me}"
    "api.photos.${globals.domains.me}"
    "cast.photos.${globals.domains.me}"
    "photos.${globals.domains.me}"
    "s3.photos.${globals.domains.me}"
    globals.services.mealie.domain
    globals.services.immich.domain
    globals.services.influxdb.domain
    globals.services.loki.domain
    globals.services.paperless.domain
    globals.services.esphome.domain
    globals.services.home-assistant.domain
    "fritzbox.${globals.domains.personal}"
  ];
in
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
    ./kea.nix
  ];

  topology.self.hardware.image = ../../topology/images/odroid-h3.png;
  topology.self.hardware.info = "O-Droid H3, 64GB RAM";

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.mode = "efi";
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
    "r8169"
  ];

  meta.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  # Connect safely via wireguard to skip authentication
  networking.hosts.${nodes.ward-web-proxy.config.wireguard.proxy-home.ipv4} = [
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

  # NOTE: state: this token is from a manually created service account
  age.secrets.firezone-gateway-token = {
    rekeyFile = config.node.secretsDir + "/firezone-gateway-token.age";
  };

  networking.hosts.${globals.net.home-lan.vlans.services.hosts.ward-web-proxy.ipv6} = homeDomains;
  networking.hosts.${globals.net.home-lan.vlans.services.hosts.ward-web-proxy.ipv4} = homeDomains;
  systemd.services.firezone-gateway.environment.HEALTH_CHECK_ADDR = "127.0.0.1:17999";
  services.firezone.gateway = {
    enable = true;
    name = "ward";
    apiUrl = "wss://${globals.services.firezone.domain}/api/";
    tokenFile = config.age.secrets.firezone-gateway-token.path;
  };

  guests =
    let
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
              zones.untrusted.interfaces = lib.mkIf (
                lib.length config.guests.${guestName}.networking.links == 1
              ) config.guests.${guestName}.networking.links;
            };
          }
        ];
      };

      mkMicrovm = guestName: {
        ${guestName} = mkGuest guestName // {
          backend = "microvm";
          microvm = {
            system = "x86_64-linux";
            baseMac = config.repo.secrets.local.networking.interfaces.lan.mac;
            interfaces.vlan-services = { };
          };
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
      // mkMicrovm "adguardhome"
      // mkMicrovm "forgejo"
      // mkMicrovm "kanidm"
      // mkMicrovm "mealie"
      // mkMicrovm "radicale"
      // mkMicrovm "vaultwarden"
      // mkMicrovm "web-proxy"
    );
}
