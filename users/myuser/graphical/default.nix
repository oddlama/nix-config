{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
{
  imports = [
    ./discord.nix
    ./firefox.nix
    ./kitty.nix
    ./signal.nix
    ./theme.nix
    ./thunderbird.nix

    # X11
    ./i3.nix
    ./flameshot.nix

    # Wayland
    ./gpu-screen-recorder.nix
    ./hyprland.nix
    ./fuzzel.nix
    ./sway.nix
    ./swaync.nix
    ./waybar.nix
  ]
  ++ lib.optionals nixosConfig.graphical.gaming.enable [
    ./games
  ];

  home = {
    packages = [
      pkgs.appimage-run
      pkgs.chromium
      pkgs.feh
      pkgs.gamescope
      pkgs.obsidian
      (pkgs.affine.override { electron_35 = pkgs.electron_37; })
      pkgs.pavucontrol
      pkgs.pinentry-gnome3 # For yubikey, gnome = gtk3 variant
      pkgs.thunderbird
      pkgs.xdg-utils
      pkgs.xdragon
      pkgs.yt-dlp
      pkgs.zathura
      pkgs.gpu-screen-recorder
      pkgs.gpu-screen-recorder-gtk
      pkgs.spotify
    ];

    # TODO wrap thunderbird bin and set LC_ALL=de_DE.UTF-8 because thunderbird uses wrong date and time formatting with C.UTF-8
    # TODO pavucontrol shortcut or bar button
    # TODO keyboard stays lit on poweroff -> add systemd service to disable it on shutdown, current workaround echo -n 1 > /sys/bus/usb/devices/usb1/remove; poweroff
    # TODO neovim gitsigns toggle_deleted keybind
    # TODO neovim gitsigns stage hunk shortcut
    # TODO neovim reopening file should continue at the previous position
    # TODO thunderbird doesn't use passwords from password command
    # TODO accounts.concats accounts.calendar
    # TODO VP9 hardware video decoding blocklisted

    persistence."/state".directories = [
      "Downloads" # config.xdg.userDirs.download (infinite recursion)
      ".local/share/invokeai"
      ".local/share/orca-slicer"
      ".local/share/kicad"
      ".cache/kicad"
      ".cache/spotify"
    ];

    persistence."/persist".directories = [
      "projects"
      "Pictures" # config.xdg.userDirs.pictures (infinite recursion)
      "Videos" # This is where I store clips from gpu-screen-recorder-gtk
      ".config/AFFiNE"
      ".config/AusweisApp"
      ".config/OrcaSlicer"
      ".config/kicad"
      ".config/gh"
      ".config/gh-dash"
      ".config/gpu-screen-recorder"
      ".config/obsidian"
      ".config/spotify"
      ".factorio" # XDG spec? nah, apprently overrated.
    ];
  };

  xdg.mimeApps.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config.common = {
      default = [
        "gtk"
        "hyprland"
      ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
      "org.freedesktop.portal.FileChooser" = [ "xdg-desktop-portal-gtk" ];
    };
    extraPortals = [
      # automatically added by hyprland module
      #pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };
}
