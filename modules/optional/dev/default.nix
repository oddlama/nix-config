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
    ./embedded.nix
    ./yubikey.nix
  ];

  environment.systemPackages = [pkgs.man-pages pkgs.man-pages-posix];
  environment.enableDebugInfo = true;

  # Add the agenix-rekey sandbox path permanently to avoid adding myself to trusted-users
  nix.settings.extra-sandbox-paths = ["/var/tmp/agenix-rekey"];

  environment.persistence."/state".directories = [
    {
      directory = "/var/tmp/agenix-rekey";
      mode = "1777";
    }
    {
      directory = "/var/tmp/nix-import-encrypted"; # Decrypted repo-secrets can be kept
      mode = "1777";
    }
  ];

  services.nixseparatedebuginfod.enable = true;
}
