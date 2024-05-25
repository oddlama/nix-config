{pkgs, ...}: {
  services.udev.packages = [pkgs.stlink];
}
