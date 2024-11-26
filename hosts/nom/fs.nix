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
      m2-ssd = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.m2-ssd}";
        content = {
          type = "gpt";
          partitions = {
            rpool = lib.disko.gpt.partLuksZfs disks.m2-ssd "rpool" "100%";
          };
        };
      };
      boot-ssd = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.boot-ssd}";
        content = {
          type = "gpt";
          partitions = {
            efi = lib.disko.gpt.partEfi "8G";
            swap = lib.disko.gpt.partSwap "100%";
          };
        };
      };
    };
    zpool = {
      rpool = lib.disko.zfs.mkZpool { datasets = lib.disko.zfs.impermanenceZfsDatasets; };
    };
  };
}
