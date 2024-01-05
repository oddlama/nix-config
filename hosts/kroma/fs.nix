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
            (partEfi "efi" "0%" "1GiB")
            (partSwap "swap" "1GiB" "17GiB")
            (partLuksZfs disks.m2-ssd "rpool" "17GiB" "100%")
          ];
        };
      };
      #data-hdd = {
      #  type = "disk";
      #  device = "/dev/disk/by-id/${config.repo.secrets.local.disk.data-hdd}";
      #  content = with lib.disko.gpt; {
      #    type = "table";
      #    format = "gpt";
      #    partitions = [
      #      (partLuksZfs "data" "0%" "100%")
      #    ];
      #  };
      #};
    };
    zpool = with lib.disko.zfs; {
      rpool = mkZpool {datasets = impermanenceZfsDatasets;};
    };
  };
}
