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

  services.nixseparatedebuginfod.enable = true;
  nix.settings.allowed-users = ["nixseparatedebuginfod"];
}
