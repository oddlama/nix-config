{
  pkgs,
  lib,
  minimal,
  ...
}:
lib.optionalAttrs (!minimal) {
  imports = [
    ./yubikey.nix
  ];

  documentation = {
    dev.enable = true;
    man.enable = true;
    info.enable = lib.mkForce false;
  };

  environment.systemPackages = [
    pkgs.man-pages
    pkgs.man-pages-posix
  ];
  environment.enableDebugInfo = true;

  environment.persistence."/state".directories = [
    {
      directory = "/var/tmp/nix-import-encrypted"; # Decrypted repo-secrets can be kept
      mode = "1777";
    }
  ];

  services.nixseparatedebuginfod.enable = true;

  # For embedded development
  services.udev.packages = [ pkgs.stlink ];
}
