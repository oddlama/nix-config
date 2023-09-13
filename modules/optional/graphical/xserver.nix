{
  services.xserver = {
    enable = true;
    dpi = 96;
    displayManager.startx.enable = true;
    desktopManager.xterm.enable = false;
    autoRepeatDelay = 235;
    autoRepeatInterval = 60;
    videoDrivers = ["modesetting"];
    libinput = {
      enable = true;
      mouse.accelProfile = "flat";
      mouse.accelSpeed = "0";
      # touchpad = {
      #   accelProfile = "flat";
      #   accelSpeed = "0.5";
      #   naturalScrolling = true;
      #   disableWhileTyping = true;
      # };
    };
    layout = "de";
    xkbVariant = "nodeadkeys";
  };
  services.autorandr.enable = true;
}
