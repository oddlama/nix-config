{
  config,
  lib,
  ...
}: let
  inherit (config.repo.secrets.local) disks;
in {
  disko.devices = {
    disk = {
      m2-ssd = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.m2-ssd}";
        content = with lib.disko.gpt; {
          type = "gpt";
          partitions = {
            rpool = partLuksZfs disks.m2-ssd "rpool" "100%";
          };
        };
      };
      boot-ssd = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.boot-ssd}";
        content = with lib.disko.gpt; {
          type = "gpt";
          partitions = {
            efi = partEfi "8G";
            swap = partSwap "100%";
          };
        };
      };
    };
    zpool = with lib.disko.zfs; {
      rpool = mkZpool {datasets = impermanenceZfsDatasets;};
    };
  };
}
