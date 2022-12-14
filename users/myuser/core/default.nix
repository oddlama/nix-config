{pkgs, ...}: {
  imports = [
    #./atuin.nix
    #./bash.nix
    #./btop.nix
    #./fish.nix
    #./git.nix
    #./htop.nix
    #./neovim
    #./ssh.nix
    #./starship.nix
    #./tmux.nix
    #./xdg.nix
    #./zsh.nix
  ];

  home = {
    username = "myuser";
    stateVersion = "22.11";
    packages = with pkgs; [
      bandwhich
      btop
      colorcheck
      fd
      kalker
      neofetch
      rclone
      ripgrep
      rsync
      tree
    ];
    shellAliases = {
      l = "ls -lahF --group-directories-first --show-control-chars --quoting-style=escape --color=auto";
      t = "tree -F --dirsfirst -L 2";
      tt = "tree -F --dirsfirst -L 3 --filelimit 16";
      ttt = "tree -F --dirsfirst -L 6 --filelimit 16";
      cpr = "rsync -axHAWXS --numeric-ids --info=progress2";

      md = "mkdir";
      rmd = "rm --one-file-system -d";
      cp = "cp -vi";
      mv = "mv -vi";
      rm = "rm --one-file-system -I";
      chmod = "chmod -c --preserve-root";
      chown = "chown -c --preserve-root";

      vim = "nvim";
      ip = "ip --color";
      tmux = "tmux -2";
      rg = "rg -S";

      p = "cd ~/projects";
    };
  };

  programs = {
    atuin = {
      enable = true;
      settings.auto_sync = false;
    };
    bat.enable = true;
    fzf.enable = true;
    gpg.enable = true;
  };

  xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";
}
