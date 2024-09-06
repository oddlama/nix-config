{
  lib,
  nixosConfig,
  pkgs,
  ...
}: {
  imports =
    [
      ./discord.nix
      ./firefox.nix
      ./kitty.nix
      ./signal.nix
      ./theme.nix
      ./thunderbird.nix
      ./ts3.nix

      # X11
      ./i3.nix
      ./flameshot.nix
      ./wired-notify.nix

      # Wayland
      ./gpu-screen-recorder.nix
      ./hyprland.nix
      ./rofi.nix
      ./swaync.nix
      ./swww.nix
      ./waybar.nix
      ./whisper-overlay.nix
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
    # TODO make screenshot copy work even if notification fails (set -e does its thing here)
    # TODO pavucontrol shortcut or bar button
    # TODO keyboard stays lit on poweroff -> add systemd service to disable it on shutdown
    # TODO on neogit close do neotree update
    # TODO neovim gitsigns toggle_deleted keybind
    # TODO neovim gitsigns stage hunk shortcut
    # TODO neovim directtly opening file has different syntax
    # TODO neovim reopening file should continue at the previous position
    # TODO thunderbird doesn't use passwords from password command
    # TODO accounts.concats accounts.calendar
    # TODO mod+f1-4 for left monitor?
    # TODO sway shortcuts
    # TODO VP9 hardware video decoding blocklisted

    persistence."/state".directories = [
      "Downloads" # config.xdg.userDirs.download (infinite recursion)
      ".local/share/invokeai"
      ".local/share/orca-slicer"
      ".local/share/kicad"
      ".cache/spotify"
    ];

    persistence."/persist".directories = [
      "projects"
      "Pictures" # config.xdg.userDirs.pictures (infinite recursion)
      "Videos" # This is where I store clips from gpu-screen-recorder-gtk
      ".config/AusweisApp"
      ".config/OrcaSlicer"
      ".config/kicad"
      ".config/gh"
      ".config/gh-dash"
      ".config/gpu-screen-recorder"
      ".config/obsidian"
      ".config/spotify"
    ];
  };

  xdg.mimeApps.enable = true;
}
