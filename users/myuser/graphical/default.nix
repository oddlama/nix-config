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
      ./sway.nix
    ]
    ++ lib.optionals (nixosConfig.node.name == "potksed") [
      ./games/lutris.nix
      #./games/steam.nix
    ];

  home = {
    packages = with pkgs; [
      thunderbird
      chromium
      zathura
      feh
      sirula
    ];

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
  };

  xdg.mimeApps.enable = true;
}
