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
    ./promtail.nix

    ./kanidm.nix
    ./grafana.nix
    ./loki.nix
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci" "r8169"];

  #ddclient = defineVm;
  #kanidm = defineVm;
  #gitea/forgejo = defineVm;
  #vaultwarden = defineVm;
  #samba+wsdd = defineVm;
  #fasten-health = defineVm;
  #immich = defineVm;
  #paperless = defineVm;
  #radicale = defineVm;
  #minecraft = defineVm;

  #prometheus
  #influxdb

  #maddy = defineVm;
  #anonaddy = defineVm;

  #automatic1111 = defineVm;
  #invokeai = defineVm;
}
