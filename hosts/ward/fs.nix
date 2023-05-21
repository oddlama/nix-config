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
            (partEfi "efi" "0%" "1GiB")
            (partSwap "swap" "1GiB" "17GiB")
            (partLuksZfs "rpool" "17GiB" "100%")
          ];
        };
      };
    };
    zpool = with extraLib.disko.zfs; {
      rpool =
        defaultZpoolOptions
        // {
          datasets = {
            "local" = unmountable;
            "local/root" =
              filesystem "/"
              // {
                postCreateHook = "zfs snapshot rpool/local/root@blank";
              };
            "local/nix" = filesystem "/nix";
            "safe" = unmountable;
            "safe/persist" = filesystem "/persist";
            "safe/vms" = unmountable;
          };
        };
    };
  };

  fileSystems."/persist".neededForBoot = true;

  # After importing the rpool, rollback the root system to be empty.
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
