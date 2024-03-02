{
  config,
  lib,
  ...
}: let
  inherit (config.repo.secrets.local) disks;
in {
  disko.devices = {
    disk = {
      ${disks.mmc} = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.mmc}";
        content = with lib.disko.gpt; {
          type = "gpt";
          partitions = {
            efi =
              partEfi "0%" "1GiB"
              // {
                # FIXME: Needed because partlabels are 💩: https://github.com/nix-community/disko/issues/551
                device = "/dev/disk/by-id/${disks.mmc}-part1";
              };
            swap =
              partSwap "1GiB" "9GiB"
              // {
                # FIXME: Needed because partlabels are 💩: https://github.com/nix-community/disko/issues/551
                device = "/dev/disk/by-id/${disks.mmc}-part2";
              };
            "rpool_${disks.mmc}" =
              partLuksZfs disks.mmc "rpool" "9GiB" "100%"
              // {
                # FIXME: Needed because partlabels are 💩: https://github.com/nix-community/disko/issues/551
                device = "/dev/disk/by-id/${disks.mmc}-part3";
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
