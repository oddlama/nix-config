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
            grub =
              partGrub "0%" "1MiB"
              // {
                # FIXME: Needed because partlabels are 💩: https://github.com/nix-community/disko/issues/551
                device = "/dev/disk/by-id/${disks.main}-part1";
              };
            bios =
              partEfi "1MiB" "512MiB"
              // {
                # FIXME: Needed because partlabels are 💩: https://github.com/nix-community/disko/issues/551
                device = "/dev/disk/by-id/${disks.main}-part2";
              };
            "rpool_${disks.main}" =
              partLuksZfs disks.main "rpool" "512MiB" "100%"
              // {
                # FIXME: Needed because partlabels are 💩: https://github.com/nix-community/disko/issues/551
                device = "/dev/disk/by-id/${disks.main}-part3";
              };
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
