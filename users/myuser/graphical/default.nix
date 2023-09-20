{
  lib,
  pkgs,
  nixosConfig,
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
      pinentry # For yubikey
      sirula
      gamescope
      thunderbird
      xdg-utils
      xdragon
      yt-dlp
      zathura
    ];

    # TODO nix repl cltr+del doesnt work
    # TODO wrap neovim for kitty hist
    # TODO neovim gitsigns toggle_deleted keybind
    # TODO neovim gitsigns stage hunk shortcut
    # TODO neovim directtly opening file has different syntax
    # TODO neovim reopening file should continue at the previous position
    # TODO thunderbird doesn't use passwords from password command
    # TODO rotating wallpaper
    # TODO thunderbird date time format is wrong even though this is C.utf8
    # TODO yubikey pinentry is curses but should be graphical
    # TODO accounts.concats accounts.calendar
    # TODO test different pinentrys (pinentry gtk?)
    # TODO agenix rekey edit secret should create temp files with same extension
    # TODO mod+f1-4 for left monitor?
    # TODO autostart signal, firefox (both windows), etc.
    # TODO repo secrets caches in /tmp which is removed each reboot and could be improved
    # TODO entering devshell takes some time after reboot
    # TODO screenshot selection/all and copy clipboard
    # TODO screenshot selection/all and save
    # TODO screenshot selection and scan qr and copy clipboard
    # TODO screenshot selection and ocr and copy clipboard
    # TODO sway shortcuts
    # TODO kitty terminfo missing with ssh root@localhost
    # TODO nvim coloscheme missing on reboot.... what state is missing?
    # TODO VP9 hardware video decoding blocklisted
    # TODO gpg switch to sk
    # TODO some font icons not showing neovim because removed from nerdfonts, replace with bertter .

    persistence."/persist".directories = [
      "projects"
    ];
  };

  xdg.mimeApps.enable = true;
}
