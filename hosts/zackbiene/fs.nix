{
  config,
  lib,
  ...
}:
let
  inherit (config.repo.secrets.local) disks;
in
{
  disko.devices = {
    disk = {
      mmc = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.mmc}";
        content = {
          type = "gpt";
          partitions = {
            efi = lib.disko.gpt.partEfi "1G";
            swap = lib.disko.gpt.partSwap "8G";
            rpool = lib.disko.gpt.partLuksZfs disks.mmc "rpool" "100%";
          };
        };
      };
    };
    zpool = {
      rpool = lib.disko.zfs.mkZpool { datasets = lib.disko.zfs.impermanenceZfsDatasets; };
    };
  };
}
