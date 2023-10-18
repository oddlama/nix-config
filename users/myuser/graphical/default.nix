{
  lib,
  nixosConfig,
  pkgs,
  ...
}: {
  imports =
    [
      ./wired-notify.nix
      ./discord.nix
      ./firefox.nix
      ./flameshot.nix
      ./kitty.nix
      ./signal.nix
      ./theme.nix
      ./thunderbird.nix
      # XXX: disabled for the time being because gaming under nvidia+wayland has too many bugs
      # XXX: retest this in the future. Problems were flickering under gles, black screens and refresh issues under vulkan, black wine windows.
      # ./sway.nix
      ./i3.nix
    ]
    ++ lib.optionals nixosConfig.graphical.gaming.enable [
      ./games/bottles.nix
      ./games/minecraft.nix
    ];

  home = {
    packages = with pkgs; [
      appimage-run
      chromium
      feh
      gamescope
      obsidian
      pavucontrol
      pinentry-gnome # For yubikey, gnome = gtk3 variant
      thunderbird
      xdg-utils
      xdragon
      yt-dlp
      zathura
    ];

    # TODO wrap thunderbird bin and set LC_ALL=de_DE.UTF-8 because thunderbird uses wrong date and time formatting with C.UTF-8
    # TODO make screenshot copy work even if notification fails (set -e does its thing here)
    # TODO pavucontrol shortcut or bar button
    # TODO audible bell in qt pinentry drives me nuts
    # TODO secureboot -> use pam yubikey login
    # TODO keyboard stays lit on poweroff -> add systemd service to disable it on shutdown
    # TODO on neogit close do neotree update
    # TODO kitty terminfo missing with ssh root@localhost
    # TODO nix repl cltr+del doesnt work
    # TODO wrap neovim for kitty hist
    # TODO neovim gitsigns toggle_deleted keybind
    # TODO neovim gitsigns stage hunk shortcut
    # TODO neovim directtly opening file has different syntax
    # TODO neovim reopening file should continue at the previous position
    # TODO thunderbird doesn't use passwords from password command
    # TODO rotating wallpaper
    # TODO yubikey pinentry is curses but should be graphical
    # TODO accounts.concats accounts.calendar
    # TODO test different pinentrys (pinentry gtk?)
    # TODO agenix rekey edit secret should create temp files with same extension
    # TODO mod+f1-4 for left monitor?
    # TODO autostart signal, firefox (both windows), etc.
    # TODO repo secrets caches in /tmp which is removed each reboot and could be improved
    # TODO sway shortcuts
    # TODO VP9 hardware video decoding blocklisted
    # TODO gpg switch to sk
    # TODO some font icons not showing neovim because removed from nerdfonts, replace with bertter .

    persistence."/state".directories = [
      "Downloads" # config.xdg.userDirs.download (infinite recursion)
    ];

    persistence."/persist".directories = [
      "projects"
      "Pictures" # config.xdg.userDirs.pictures (infinite recursion)
      ".config/obsidian"
    ];
  };

  xdg.mimeApps.enable = true;
}
