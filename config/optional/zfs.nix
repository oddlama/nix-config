{
  config,
  lib,
  pkgs,
  ...
}: {
  boot.supportedFilesystems = ["zfs"];

  # The root pool should never be imported forcefully.
  # Failure to import is important to notice!
  boot.zfs.forceImportRoot = false;

  environment.systemPackages = with pkgs; [zfs];

  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "weekly";
    };
    trim = {
      enable = true;
      interval = "weekly";
    };
  };

  services.telegraf.extraConfig.inputs = lib.mkIf config.services.telegraf.enable {
    zfs.poolMetrics = true;
  };

  # TODO remove once this is upstreamed
  boot.initrd.systemd.services."zfs-import-rpool".after = ["cryptsetup.target"];

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
