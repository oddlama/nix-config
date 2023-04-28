{
  extraLib,
  pkgs,
  ...
}: {
  disko.devices = {
    disk = {
      m2-ssd = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NL0TC36758M";
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "efi";
              start = "2048";
              end = "1GiB";
              fs-type = "fat32";
              bootable = true;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            }
            {
              name = "swap";
              start = "1GiB";
              end = "17GiB";
              fs-type = "linux-swap";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            }
            {
              name = "rpool";
              start = "17GiB";
              end = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            }
          ];
        };
      };
    };
    zpool = extraLib.disko.defineEncryptedZpool "rpool" {};
  };

  boot.initrd.systemd.services = {
    impermanence-root = {
      wantedBy = ["initrd.target"];
      after = ["zfs-import-rpool.service"];
      before = ["sysroot.mount"];
      unitConfig.DefaultDependencies = "no";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.zfs}/bin/zfs rollback -r rpool/local/root@blank";
      };
    };
  };
}
