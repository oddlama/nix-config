{
  config,
  lib,
  ...
}: let
  inherit (config.repo.secrets.local) disks;
in {
  disko.devices = {
    disk = {
      ${disks.m2-ssd} = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.m2-ssd}";
        content = with lib.disko.gpt; {
          type = "table";
          format = "gpt";
          partitions = [
            (partLuksZfs disks.m2-ssd "rpool" "0%" "100%")
          ];
        };
      };
      ${disks.boot-ssd} = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.boot-ssd}";
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
}
