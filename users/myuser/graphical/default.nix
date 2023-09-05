{pkgs, ...}: {
  imports = [
    ./discord.nix
    ./firefox.nix
    ./kitty.nix
    ./signal.nix
    ./sway.nix
  ];

  home = {
    packages = with pkgs; [
      thunderbird
      chromium
      zathura
      feh
    ];

    # TODO sway config
    # TODO kitty terminfo missing with ssh root@localhost
    # TODO nvim coloscheme missing on reboot.... what state is missing?
    # TODO VP9 hardware video decoding blocklisted
    # TODO gpg switch to sk
    # TODO some font icons not showing neovim

    shellAliases = {
      p = "cd ~/projects";
      zf = "zathura --fork";
    };

    persistence."/persist".directories = [
      "projects"
    ];
  };
}
