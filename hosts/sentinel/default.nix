{
  config,
  lib,
  ...
}: {
  imports = [
    ../common/core
    ../common/initrd-ssh.nix
    ../common/zfs.nix

    ./fs.nix
    ./net.nix
    ./nginx.nix
  ];

  boot.loader.timeout = lib.mkDefault 2;
  boot.loader.grub = {
    enable = true;
    efiSupport = false;
    devices = ["/dev/disk/by-id/${config.repo.secrets.local.disk.main}"];
  };
  console.earlySetup = true;
}
