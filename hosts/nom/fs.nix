{
  config,
  lib,
  ...
}: {
  disko.devices = {
    disk = {
      m2-ssd = {
        type = "disk";
        device = "/dev/disk/by-id/${config.repo.secrets.local.disk.m2-ssd}";
        content = with lib.disko.gpt; {
          type = "table";
          format = "gpt";
          partitions = [
            (partLuksZfs "rpool" "0%" "100%")
          ];
        };
      };
      boot-ssd = {
        type = "disk";
        device = "/dev/disk/by-id/${config.repo.secrets.local.disk.boot-ssd}";
        content = with lib.disko.gpt; {
          type = "table";
          format = "gpt";
          partitions = [
            (partEfi "efi" "0%" "8GiB")
            (partSwap "swap" "8GiB" "100%")
          ];
        };
      };
    };
    zpool = with lib.disko.zfs; {
      rpool = mkZpool {datasets = impermanenceZfsDatasets;};
    };
  };

  boot.initrd.luks.devices.enc-rpool.allowDiscards = true;
}
