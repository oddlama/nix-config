{
  config,
  lib,
  ...
}: let
  inherit (config.repo.secrets.local) disks;
in {
  disko.devices = {
    disk = {
      ${disks.main} = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.main}";
        content = with lib.disko.gpt; {
          type = "table";
          format = "gpt";
          partitions = [
            (partGrub "grub" "0%" "1MiB")
            (partEfi "bios" "1MiB" "512MiB")
            (partLuksZfs disks.main "rpool" "512MiB" "100%")
          ];
        };
      };
    };
    zpool = with lib.disko.zfs; {
      rpool = mkZpool {datasets = impermanenceZfsDatasets;};
    };
  };

  boot.loader.grub.devices = ["/dev/disk/by-id/${disks.main}"];
}
