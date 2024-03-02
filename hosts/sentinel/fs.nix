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
          type = "gpt";
          partitions = {
            grub = partGrub "0%" "1MiB";
            bios = partEfi "1MiB" "512MiB";
            "rpool_${disks.main}" = partLuksZfs disks.main "rpool" "512MiB" "100%";
          };
        };
      };
    };
    zpool = with lib.disko.zfs; {
      rpool = mkZpool {datasets = impermanenceZfsDatasets;};
    };
  };

  boot.loader.grub.devices = ["/dev/disk/by-id/${disks.main}"];
}
