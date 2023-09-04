{pkgs, ...}: {
  imports = [
    ./kitty.nix
  ];

  wayland.windowManager.sway = {
    enable = true;
    config = rec {
      modifier = "Mod4";
      terminal = "kitty";

      focus.followMouse = false;
      input = {
        "*" = {
          xkb_layout = "de";
          repeat_delay = "235";
          repeat_rate = "60";
        };
      };
    };
  };

  home.packages = with pkgs; [
    xdg-utils
    wdisplays
    wl-clipboard
    pinentry
    xdragon

    discord
    firefox
    thunderbird
    signal-desktop
    chromium
    zathura
    feh
  ];
  home.sessionVariables.NIXOS_OZONE_WL = 1;
  home.sessionVariables.WLR_NO_HARDWARE_CURSORS = 1;
  home.sessionVariables.WLR_RENDERER = "vulkan";
  # TODO VP9 hardware video decoding blocklisted
  # TODO xdg-open
  # TODO gpg orswitch to sk
  # TODO mouse speed
  # TODO persist tmp malte ddelete.
  # TODO ncdu

  # Needed to fix cursors in firefox under wayland, see https://github.com/NixOS/nixpkgs/issues/207339#issuecomment-1374497558
  gtk = {
    enable = true;
    theme = {
      package = pkgs.gnome.gnome-themes-extra;
      name = "Adwaita-dark";
    };
  };
}
