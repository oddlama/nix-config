{
  nom = {
    disk = {
      "Intenso_SSD_3833430-532201046" = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Intenso_SSD_3833430-532201046";
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              type = "partition";
              name = "efi";
              start = "0";
              end = "8GiB";
              fs-type = "fat32";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            }
            {
              type = "partition";
              name = "swap";
              start = "8GiB";
              end = "100%";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            }
          ];
        };
      };
      "Samsung_SSD_980_PRO_1TB_S5GXNX1T325329W" = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_980_PRO_1TB_S5GXNX1T325329W";
        content = {
          type = "zfs";
          pool = "zpool";
        };
      };
    };
    rpool = {
      type = "zpool";
      mode = "mirror";
      rootFsOptions = {
        compression = "zstd";
        acltype = "posix";
        atime = "off";
        xattr = "sa";
        dnodesize = "auto";
        mountpoint = "none";
        canmount = "off";
        devices = "off";
        encryption = "aes-256-gcm";
        keyformat = "passphrase";
        keylocation = "prompt";
        "autobackup:snap" = "true";
        "autobackup:home" = "true";
      };
      options = {
        ashift = "12";
        bootfs = "rpool/root/nixos";
      };
      datasets = {
        "root" = {
          zfs_type = "filesystem";
        };
        "root/nixos" = {
          zfs_type = "filesystem";
          options = {
            canmount = "on";
            mountpoint = "/";
          };
        };
        "home" = {
          zfs_type = "filesystem";
        };
        "home/root" = {
          zfs_type = "filesystem";
          options = {
            canmount = "on";
            mountpoint = "/root";
          };
        };
      };
    };
  };
}
