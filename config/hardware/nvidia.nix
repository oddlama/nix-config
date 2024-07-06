{
  lib,
  minimal,
  pkgs,
  ...
}:
lib.optionalAttrs (!minimal) {
  boot.blacklistedKernelModules = ["nouveau"];
  services.xserver.videoDrivers = lib.mkForce ["nvidia"];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        vaapiVdpau
        nvidia-vaapi-driver
      ];
    };
    nvidia = {
      modesetting.enable = true;
      open = true;
      powerManagement.enable = true;
    };
  };
}
