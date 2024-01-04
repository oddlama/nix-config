{
  config,
  lib,
  ...
}: {
  disko.devices = {
    disk = {
      mmc = {
        type = "disk";
        device = "/dev/disk/by-id/${config.repo.secrets.local.disk.mmc}";
        content = with lib.disko.gpt; {
          type = "table";
          format = "gpt";
          partitions = [
            (partEfi "efi" "0%" "1GiB")
            (partSwap "swap" "1GiB" "9GiB")
            (partLuksZfs "rpool" "9GiB" "100%")
          ];
        };
      };
    };
    zpool = with lib.disko.zfs; {
      rpool = mkZpool {datasets = impermanenceZfsDatasets;};
    };
  };
}
