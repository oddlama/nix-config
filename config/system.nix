{ pkgs, ... }:
{
  documentation.nixos.enable = false;

  # Disable sudo which is entirely unnecessary.
  security.sudo.enable = false;
  services.dbus.implementation = "broker";

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "C.UTF-8";
  console.keyMap = "de-latin1-nodeadkeys";

  # Install the kitty terminfo package for all systems.
  environment.systemPackages = [ pkgs.kitty.terminfo ];

  # And a reasonable inputrc please
  environment.etc."inputrc".source = ./inputrc;
}
