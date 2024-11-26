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
      m2-ssd = {
        type = "disk";
        device = "/dev/disk/by-id/${disks.m2-ssd}";
        content = {
          type = "gpt";
          partitions = {
            efi = lib.disko.gpt.partEfi "1G";
            swap = lib.disko.gpt.partSwap "16G";
            rpool = lib.disko.gpt.partLuksZfs disks.m2-ssd "rpool" "100%";
          };
        };
      };
    };
    zpool = {
      rpool = lib.disko.zfs.mkZpool {
        datasets = lib.disko.zfs.impermanenceZfsDatasets // {
          "safe/guests" = lib.disko.zfs.unmountable;
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
}
