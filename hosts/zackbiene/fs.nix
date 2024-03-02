{
  config,
  lib,
  ...
}: let
  inherit (config.repo.secrets.local) disks;
in {
  disko.devices = {
    disk = {
      ${disks.mmc} = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.mmc}";
        content = with lib.disko.gpt; {
          type = "gpt";
          partitions = {
            efi = partEfi "0%" "1GiB";
            swap = partSwap "1GiB" "9GiB";
            "rpool_${disks.mmc}" = partLuksZfs disks.mmc "rpool" "9GiB" "100%";
          };
        };
      };
    };
    zpool = with lib.disko.zfs; {
      rpool = mkZpool {datasets = impermanenceZfsDatasets;};
    };
  };
}
