{
  config,
  lib,
  ...
}: let
  inherit (config.repo.secrets.local) disks;
in {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.main}";
        content = with lib.disko.gpt; {
          type = "gpt";
          partitions = {
            grub = partGrub;
            bios = partBoot "512M";
            rpool = partLuksZfs disks.main "rpool" "100%";
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
