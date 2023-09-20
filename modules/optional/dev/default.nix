{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixseparatedebuginfod.nixosModules.default
    ./documentation.nix
    ./yubikey.nix
  ];

  environment.systemPackages = [pkgs.man-pages pkgs.man-pages-posix];
  environment.enableDebugInfo = true;
  # XXX: TODO reenable once https://github.com/symphorien/nixseparatedebuginfod/issues/11 is answered
  services.nixseparatedebuginfod.enable = false;
}
