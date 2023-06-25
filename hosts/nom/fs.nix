{
  config,
  lib,
  extraLib,
  pkgs,
  ...
}: {
  disko.devices = {
    disk = {
      m2-ssd = {
        type = "disk";
        device = "/dev/disk/by-id/${config.repo.secrets.local.disk.m2-ssd}";
        content = with extraLib.disko.gpt; {
          type = "table";
          format = "gpt";
          partitions = [
            (partLuksZfs "rpool" "0%" "100%")
          ];
        };
      };
      boot-ssd = {
        type = "disk";
        device = "/dev/disk/by-id/${config.repo.secrets.local.disk.boot-ssd}";
        content = with extraLib.disko.gpt; {
          type = "table";
          format = "gpt";
          partitions = [
            (partEfi "efi" "0%" "8GiB")
            (partSwap "swap" "8GiB" "100%")
          ];
        };
      };
    };
    zpool = with extraLib.disko.zfs; {
      rpool = defaultZpoolOptions // {datasets = defaultZfsDatasets;};
    };
  };

  # TODO remove once this is upstreamed
  boot.initrd.systemd.services."zfs-import-rpool".after = ["cryptsetup.target"];
  fileSystems."/state".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;

  # After importing the rpool, rollback the root system to be empty.
  boot.initrd.systemd.services.impermanence-root = {
    wantedBy = ["initrd.target"];
    after = ["zfs-import-rpool.service"];
    before = ["sysroot.mount"];
    unitConfig.DefaultDependencies = "no";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.zfs}/bin/zfs rollback -r rpool/local/root@blank";
    };
  };
}
