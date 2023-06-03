{
  config,
  extraLib,
  pkgs,
  ...
}: {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/${config.repo.secrets.local.disk.main}";
        content = with extraLib.disko.gpt; {
          type = "table";
          format = "gpt";
          partitions = [
            (partGrub "grub" "0%" "1MiB")
            (partEfi "bios" "1MiB" "512MiB")
            (partLuksZfs "rpool" "512MiB" "100%")
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
            "local/state" = filesystem "/state";
            "safe" = unmountable;
            "safe/persist" = filesystem "/persist";
          };
        };
    };
  };

  boot.loader.grub.devices = ["/dev/disk/by-id/${config.repo.secrets.local.disk.main}"];
  boot.initrd.luks.devices.enc-rpool.allowDiscards = true;
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
