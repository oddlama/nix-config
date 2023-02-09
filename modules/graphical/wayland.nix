{pkgs, ...}: {
  environment.systemPackages = with pkgs; [wayland];
  services.dbus.enable = true;
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    # gtk portal needed to make gtk apps happy
    extraPortals = with pkgs; [xdg-desktop-portal-gtk];
  };
}
