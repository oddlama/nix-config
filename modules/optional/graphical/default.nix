{lib, ...}: let
  inherit
    (lib)
    mkOption
    types
    ;
in {
  imports = [
    ./fonts.nix
    ./wayland.nix
    ./xserver.nix
    ./steam.nix
  ];

  options.graphical.gaming.enable = mkOption {
    description = "Enables gaming on this machine and will add a lot of gaming related packages and configuration.";
    default = false;
    type = types.bool;
  };

  config = {
    # Needed for gtk
    programs.dconf.enable = true;
  };
}
