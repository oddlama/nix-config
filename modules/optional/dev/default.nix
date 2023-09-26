{
  inputs,
  pkgs,
  lib,
  minimal,
  ...
}:
lib.optionalAttrs (!minimal) {
  imports = [
    inputs.nixseparatedebuginfod.nixosModules.default
    ./documentation.nix
    ./yubikey.nix
  ];

  environment.systemPackages = [pkgs.man-pages pkgs.man-pages-posix];
  environment.enableDebugInfo = true;

  # Add the agenix-rekey sandbox path permanently to avoid adding myself to trusted-users
  nix.settings.extra-sandbox-paths = ["/var/tmp/agenix-rekey"];

  services.nixseparatedebuginfod.enable = true;
  nix.settings.allowed-users = ["nixseparatedebuginfod"];
}
