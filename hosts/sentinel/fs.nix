{
  config,
  inputs,
  ...
}: let
  disko = import ../../lib/disko.nix inputs;
in {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/${config.repo.secrets.local.disk.main}";
        content = with disko.gpt; {
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
    zpool = with disko.zfs; {
      rpool = defaultZpoolOptions // {datasets = defaultZfsDatasets;};
    };
  };

  boot.loader.grub.devices = ["/dev/disk/by-id/${config.repo.secrets.local.disk.main}"];
  boot.initrd.luks.devices.enc-rpool.allowDiscards = true;
}
