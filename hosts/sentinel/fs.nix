{
  config,
  lib,
  ...
}: {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/${config.repo.secrets.local.disk.main}";
        content = with lib.disko.gpt; {
          type = "table";
          format = "gpt";
          partitions = [
            (partGrub "grub" "0%" "1MiB")
            (partEfi "bios" "1MiB" "512MiB")
            (partLuksZfs "rpool" "512MiB" "100%")
          ];
        };
      };
    };
    zpool = with lib.disko.zfs; {
      rpool = defaultZpoolOptions // {datasets = defaultZfsDatasets;};
    };
  };

  boot.loader.grub.devices = ["/dev/disk/by-id/${config.repo.secrets.local.disk.main}"];
  boot.initrd.luks.devices.enc-rpool.allowDiscards = true;
}
