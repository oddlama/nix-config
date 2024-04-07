{
  config,
  lib,
  ...
}: let
  inherit (config.repo.secrets.local) disks;
in {
  disko.devices = {
    disk = {
      mmc = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.mmc}";
        content = with lib.disko.gpt; {
          type = "gpt";
          partitions = {
            efi = partEfi "1G";
            swap = partSwap "8G";
            rpool = partLuksZfs disks.mmc "rpool" "100%";
          };
        };
      };
    };
    zpool = with lib.disko.zfs; {
      rpool = mkZpool {datasets = impermanenceZfsDatasets;};
    };
  };
}
