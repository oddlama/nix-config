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

  services.zrepl = {
    enable = true;
    settings = {
      global = {
        logging = [
          {
            type = "syslog";
            level = "info";
            format = "human";
          }
        ];
        # TODO zrepl monitor
        #monitoring = [
        #  {
        #    type = "prometheus";
        #    listen = ":9811";
        #    listen_freebind = true;
        #  }
        #];
      };

      jobs = [
        {
          name = "local-snapshots";
          type = "snap";
          filesystems = {
            # "rpool/local/state<" = true;
            # "rpool/safe<" = true;
            "storage/safe<" = true;
            "storage/bunker<" = true;
          };
          snapshotting = {
            type = "periodic";
            prefix = "zrepl-";
            timestamp_format = "iso-8601";
            interval = "15m";
          };
          pruning.keep = [
            # Keep all manual snapshots
            {
              type = "regex";
              regex = "^zrepl-.*$";
              negate = true;
            }
            # Keep last n snapshots
            {
              type = "last_n";
              regex = "^zrepl-.*$";
              count = 10;
            }
            # Prune periodically
            {
              type = "grid";
              regex = "^zrepl-.*$";
              grid = lib.concatStringsSep " | " [
                "72x1h"
                "90x1d"
                "60x1w"
                "24x30d"
              ];
            }
          ];
        }
      ];
    };
  };
}
