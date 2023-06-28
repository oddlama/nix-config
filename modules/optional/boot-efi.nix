{
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 32;
    efi.canTouchEfiVariables = true;
  };
}
