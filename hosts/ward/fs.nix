{
  config,
  lib,
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
            "rpool/local/state<" = true;
            "rpool/safe<" = true;
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

  boot.initrd.luks.devices.enc-rpool.allowDiscards = true;
}
