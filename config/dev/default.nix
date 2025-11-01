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

  # NOTE: disabled temporarily. Spams my journal and uses a lot of CPU in the background at all times.
  # services.nixseparatedebuginfod.enable = true;

  # For embedded development
  users.groups.plugdev = { };
  services.udev.packages = [
    pkgs.nrf-udev
    (pkgs.runCommandLocal "probe-rs-udev-rules" { } ''
      mkdir -p $out/lib/udev/rules.d
      cp ${./69-probe-rs.rules} $out/lib/udev/rules.d/69-probe-rs.rules
    '')
  ];
}
