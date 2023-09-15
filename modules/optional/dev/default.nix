{pkgs, ...}: {
  imports = [
    ./documentation.nix
    ./yubikey.nix
  ];

  environment.enableDebugInfo = true;
  services.nixseparatedebuginfod.enable = true;
}
