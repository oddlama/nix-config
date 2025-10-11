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
      m2-ssd-1 = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.m2-ssd-1}";
        content = {
          type = "gpt";
          partitions = {
            efi = lib.disko.gpt.partEfi "1G";
            rpool = lib.disko.gpt.partLuksZfs disks.m2-ssd-1 "rpool" "100%";
          };
        };
      };
      m2-ssd-2 = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.m2-ssd-2}";
        content = lib.disko.content.luksZfs disks.m2-ssd-2 "rpool";
      };
    }
    // lib.genAttrs disks.hdds-storage (disk: {
      type = "disk";
      device = "/dev/disk/by-id/${disk}";
      content = lib.disko.content.luksZfs disk "storage";
    });
    zpool = {
      rpool = lib.disko.zfs.mkZpool {
        mode = "mirror";
        datasets = lib.disko.zfs.impermanenceZfsDatasets // {
          "safe/guests" = lib.disko.zfs.unmountable;
        };
      };
      storage = lib.disko.zfs.mkZpool {
        mode = "raidz";
        datasets = {
          "safe/guests" = lib.disko.zfs.unmountable;
        };
      };
    };
  };

  boot.initrd.systemd.services."zfs-import-storage".after = [ "cryptsetup.target" ];
}
