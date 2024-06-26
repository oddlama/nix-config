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
    nvidia = {
      modesetting.enable = true;
      nvidiaPersistenced = true;
      nvidiaSettings = true;
      open = true;
      powerManagement.enable = true;
    };
    opengl = {
      enable = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        vaapiVdpau
        nvidia-vaapi-driver
      ];
    };
  };
}
