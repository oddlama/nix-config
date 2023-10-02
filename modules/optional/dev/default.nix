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

  environment.persistence."/state".directories = [
    {
      directory = "/var/tmp/agenix-rekey";
      mode = "1777";
    }
    "/var/tmp/nix-import-encrypted" # Decrypted repo-secrets can be kept
  ];

  services.nixseparatedebuginfod = {
    enable = true;
    # We need a system-level user to be able to use nix.settings.allowed-users with it.
    # TODO: remove once https://github.com/NixOS/nix/issues/9071 is fixed
    allowUser = true;
  };
}
