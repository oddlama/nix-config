{...}: {
  imports = [
    ./nushell.nix
    ./starship.nix
    ./zsh
  ];

  home.shellAliases = {
    l = "ls -lahF --group-directories-first --show-control-chars --quoting-style=escape --color=auto";
    t = "tree -F --dirsfirst -L 2";
    tt = "tree -F --dirsfirst -L 3 --filelimit 16";
    cpr = "rsync -axHAWXS --numeric-ids --info=progress2";

    md = "mkdir";
    rmd = "rm --one-file-system -d";
    cp = "cp -vi";
    mv = "mv -vi";
    rm = "rm --one-file-system -I";
    chmod = "chmod -c --preserve-root";
    chown = "chown -c --preserve-root";

    ip = "ip --color";
    tmux = "tmux -2";
    rg = "rg -S";
  };

  programs.atuin = {
    enable = true;
    settings.auto_sync = false;
  };
}
