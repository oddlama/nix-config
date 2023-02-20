{
  fileSystems = {
    "/" = {
      device = "rpool/root/nixos";
      fsType = "zfs";
      options = ["zfsutil" "X-mount.mkdir"];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/TODO";
      fsType = "vfat";
    };
  };

  swapDevices = [];
}
