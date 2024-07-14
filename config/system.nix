{
  lib,
  pkgs,
  ...
}: {
  documentation.nixos.enable = false;

  # Disable sudo which is entierly unnecessary.
  security.sudo.enable = false;

  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = "C.UTF-8";
  console.keyMap = "de-latin1-nodeadkeys";

  # Install the kitty terminfo package for all systems.
  environment.systemPackages = [pkgs.kitty.terminfo];
}
