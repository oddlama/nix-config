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
      main = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.main}";
        content = {
          type = "gpt";
          partitions = {
            grub = lib.disko.gpt.partGrub;
            bios = lib.disko.gpt.partBoot "512M";
            rpool = lib.disko.gpt.partLuksZfs disks.main "rpool" "100%";
          };
        };
      };
    };
    zpool = {
      rpool = lib.disko.zfs.mkZpool { datasets = lib.disko.zfs.impermanenceZfsDatasets; };
    };
  };

  boot.loader.grub.devices = [ "/dev/disk/by-id/${disks.main}" ];
}
