{
  inputs,
  config,
  nodes,
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
    influxdb2.domain = nodes.sentinel.config.networking.providedDomains.influxdb;
    influxdb2.organization = "servers";
    influxdb2.bucket = "telegraf";
  };

  # TODO track my github stats
  # services.telegraf.extraConfig.inputs.github = {};

  meta.microvms.commonImports = [
    ./microvms/common.nix
  ];

  meta.microvms.vms = let
    defaults = {
      system = "x86_64-linux";
      autostart = true;
      zfs = {
        enable = true;
        pool = "rpool";
      };
      todo
      configPath =
        if nodePath != null && builtins.pathExists (nodePath + "/microvms/${name}") then
        nodePath + "/microvms/${name}"
        else if nodePath != null && builtins.pathExists (nodePath + "/microvms/${name}") then
        nodePath + "/microvms/${name}.nix"
        else null;
    };
  in {
    kanidm = defaults;
    grafana = defaults;
    loki = defaults;
    vaultwarden = defaults;
    adguardhome = defaults;
    influxdb = defaults;
  };

  #ddclient = defineVm;
  #gitea/forgejo = defineVm;
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
