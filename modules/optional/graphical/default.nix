{
  config,
  inputs,
  lib,
  minimal,
  ...
}: let
  inherit
    (lib)
    mkOption
    types
    optionalAttrs
    ;
in
  {
    options.graphical.gaming.enable = mkOption {
      description = "Enables gaming on this machine and will add a lot of gaming related packages and configuration.";
      default = false;
      type = types.bool;
    };
  }
  // optionalAttrs (!minimal) {
    imports = [
      inputs.stylix.nixosModules.stylix

      ./fonts.nix
      ./steam.nix
      ./wayland.nix
      ./xserver.nix
    ];

    config = {
      # Needed for gtk
      programs.dconf.enable = true;
      stylix = {
        # I want to choose what to style myself.
        autoEnable = false;
        polarity = "dark";
        image = config.lib.stylix.pixel "base00";
        base16Scheme = {
          base00 = "282c34";
          base01 = "353b45";
          base02 = "3e4451";
          base03 = "545862";
          base04 = "565c64";
          base05 = "abb2bf";
          base06 = "b6bdca";
          base07 = "c8ccd4";
          base08 = "e06c75";
          base09 = "d19a66";
          base0A = "e5c07b";
          base0B = "98c379";
          base0C = "56b6c2";
          base0D = "61afef";
          base0E = "c678dd";
          base0F = "be5046";
        };
      };
    };
  }
