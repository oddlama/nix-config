{
  # TODO disko
  fileSystems = {
    "/" = {
      device = "rpool/root/nixos";
      fsType = "zfs";
      options = ["zfsutil" "X-mount.mkdir"];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/c0bb3411-7af3-4901-83ea-eb2560b11784";
      fsType = "ext4";
    };
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/a4a5fee7-2b6f-4cec-9ec9-fc4b71e8055a";}
  ];
}
