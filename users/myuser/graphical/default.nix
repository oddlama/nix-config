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
      thunderbird
      xdg-utils
      xdragon
      yt-dlp
      zathura
    ];

    # TODO emoji in firefox are wrong
    # TODO screenshot selection/all and copy clipboard
    # TODO screenshot selection/all and save
    # TODO screenshot selection and scan qr and copy clipboard
    # TODO screenshot selection and ocr and copy clipboard
    # TODO sway config
    # TODO sway shortcuts
    # TODO enable nodeadkeys
    # TODO kitty terminfo missing with ssh root@localhost
    # TODO nvim coloscheme missing on reboot.... what state is missing?
    # TODO VP9 hardware video decoding blocklisted
    # TODO gpg switch to sk
    # TODO some font icons not showing neovim

    shellAliases = {
      p = "cd ~/projects";
      zf = "zathura --fork"; # XXX: do i need this or can i just xdg-open?
    };

    persistence."/persist".directories = [
      "projects"
    ];

    pointerCursor = {
      gtk.enable = true;
      name = "Adwaita-dark";
      package = pkgs.gnome.adwaita-icon-theme;
      # TODO XXX: not working
      size = 24;
    };
  };

  # Needed to fix cursors in firefox under wayland, see https://github.com/NixOS/nixpkgs/issues/207339#issuecomment-1374497558
  gtk = {
    enable = true;
    theme = {
      package = pkgs.gnome.gnome-themes-extra;
      name = "Adwaita-dark";
    };

    gtk2.extraConfig = "gtk-application-prefer-dark-theme = true";
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-cursor-theme-size = 24;
      gtk-enable-animations = true;
      gtk-xft-antialias = 1;
      gtk-xft-dpi = 160;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle = "hintslight";
      gtk-xft-rgba = "rgb";
    };
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = {
      name = "adwaita";
      package = pkgs.adwaita-qt;
    };
  };

  xdg.mimeApps.enable = true;
}
