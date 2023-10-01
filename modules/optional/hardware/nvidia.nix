{
  lib,
  minimal,
  pkgs,
  ...
}:
lib.optionalAttrs (!minimal) {
  boot.blacklistedKernelModules = ["nouveau"];
  services.xserver = {
    videoDrivers = lib.mkForce ["nvidia"];
    screenSection = ''
      Option "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
      Option "AllowIndirectGLXProtocol" "off"
      Option "TripleBuffer" "on"
    '';
  };

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
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
        vaapiVdpau
        nvidia-vaapi-driver
      ];
    };
  };
}
