# Configuration for actual physical machines
{
  config,
  lib,
  minimal,
  ...
}:
{
  hardware = {
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
  };

  services = lib.mkIf (!minimal) {
    fwupd.enable = true;
    smartd.enable = true;
    thermald.enable = builtins.elem config.nixpkgs.hostPlatform.system [ "x86_64-linux" ];
  };
}
