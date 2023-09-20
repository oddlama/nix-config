# Configuration for actual physical machines
{config, ...}: {
  hardware = {
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
  };

  services = {
    fwupd.enable = true;
    smartd.enable = true;
    thermald.enable = builtins.elem config.nixpkgs.hostPlatform.system ["x86_64-linux"];
  };
}
