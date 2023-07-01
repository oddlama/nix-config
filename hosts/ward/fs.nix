{
  config,
  lib,
  pkgs,
  ...
}: {
  disko.devices = {
    disk = {
      m2-ssd = {
        type = "disk";
        device = "/dev/disk/by-id/${config.repo.secrets.local.disk.m2-ssd}";
        content = with lib.disko.gpt; {
          type = "table";
          format = "gpt";
          partitions = [
            (partEfi "efi" "0%" "1GiB")
            (partSwap "swap" "1GiB" "17GiB")
            (partLuksZfs "rpool" "17GiB" "100%")
          ];
        };
      };
    };
    zpool = with lib.disko.zfs; {
      rpool =
        defaultZpoolOptions
        // {
          datasets =
            defaultZfsDatasets
            // {
              "safe/vms" = unmountable;
            };
        };
    };
  };

  boot.initrd.luks.devices.enc-rpool.allowDiscards = true;
}
