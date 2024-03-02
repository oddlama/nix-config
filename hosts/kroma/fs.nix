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
          type = "gpt";
          partitions = {
            efi =
              partEfi "0%" "1GiB"
              // {
                # FIXME: Needed because partlabels are 💩: https://github.com/nix-community/disko/issues/551
                device = "/dev/disk/by-id/${disks.m2-ssd}-part1";
              };
            swap =
              partSwap "1GiB" "17GiB"
              // {
                # FIXME: Needed because partlabels are 💩: https://github.com/nix-community/disko/issues/551
                device = "/dev/disk/by-id/${disks.m2-ssd}-part2";
              };
            "rpool_${disks.m2-ssd}" =
              partLuksZfs disks.m2-ssd "rpool" "17GiB" "100%"
              // {
                # FIXME: Needed because partlabels are 💩: https://github.com/nix-community/disko/issues/551
                device = "/dev/disk/by-id/${disks.m2-ssd}-part3";
              };
          };
        };
      };
    };
    zpool = with lib.disko.zfs; {
      rpool = mkZpool {datasets = impermanenceZfsDatasets;};
    };
  };
}
