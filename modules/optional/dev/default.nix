{pkgs, ...}: {
  imports = [
    ./documentation.nix
    ./yubikey.nix
  ];

  environment.systemPackages = [pkgs.man-pages pkgs.man-pages-posix];
  environment.enableDebugInfo = true;
  services.nixseparatedebuginfod.enable = true;
}
