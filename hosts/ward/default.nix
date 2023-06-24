{
  config,
  nixos-hardware,
  ...
}: {
  imports = [
    nixos-hardware.common-cpu-intel
    nixos-hardware.common-pc-ssd

    ../common/core
    ../common/hardware/intel.nix
    ../common/hardware/physical.nix
    ../common/initrd-ssh.nix
    ../common/efi.nix
    ../common/zfs.nix

    ./fs.nix
    ./net.nix
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci" "r8169"];

  extra.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  extra.telegraf = {
    enable = true;
    proxy = "sentinel";
    # TODO organization = "servers";
    # TODO bucket = "telegraf";
  };

  # TODO track my github stats
  # services.telegraf.extraConfig.inputs.github = {};

  extra.microvms.vms = let
    defaults = {
      system = "x86_64-linux";
      autostart = true;
      zfs = {
        enable = true;
        pool = "rpool";
      };
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
