{
  fileSystems = {
    "/" = {
      device = "rpool/root/nixos";
      fsType = "zfs";
      options = ["zfsutil" "X-mount.mkdir"];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/10E6-553F";
      fsType = "vfat";
    };
  };

  swapDevices = [];
}
