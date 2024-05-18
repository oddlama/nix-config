{
  services.xserver = {
    enable = true;
    dpi = 96;
    displayManager.startx.enable = true;
    desktopManager.xterm.enable = false;
    autoRepeatDelay = 235;
    autoRepeatInterval = 60;
    videoDrivers = ["modesetting"];
    xkb.layout = "de";
    xkb.variant = "nodeadkeys";
  };
  services.libinput = {
    enable = true;
    mouse = {
      accelProfile = "flat";
      accelSpeed = "0";
      middleEmulation = false;
    };
    # touchpad = {
    #   accelProfile = "flat";
    #   accelSpeed = "0.5";
    #   naturalScrolling = true;
    #   disableWhileTyping = true;
    # };
  };
  services.autorandr.enable = true;

  # Enable for Xorg debugging
  # services.xserver.modules = lib.mkBefore [(pkgs.enableDebugging pkgs.xorg.xorgserver).out];
  # environment.etc."X11/xinit/xserverrc".source = lib.mkForce (pkgs.writeShellScript "xserverrc" ''
  #   exec ${pkgs.enableDebugging pkgs.xorg.xorgserver}/bin/X ${toString config.services.xserver.displayManager.xserverArgs} "$@"
  # '');
}
