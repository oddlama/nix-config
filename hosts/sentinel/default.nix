{
  config,
  lib,
  ...
}: {
  imports = [
    ../common/core
    ../common/hardware/hetzner-cloud.nix
    ../common/bios-boot.nix
    ../common/initrd-ssh.nix
    ../common/zfs.nix

    ./fs.nix
    ./net.nix

    ./acme.nix
    ./oauth2.nix
  ];

  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;

  extra.promtail = {
    enable = true;
    proxy = "sentinel";
  };
}
