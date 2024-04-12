{...}: {
  imports = [
    ./starship.nix
    ./nushell
    ./zsh
  ];

  programs.zoxide = {
    enable = true;
    options = ["--cmd p"];
  };

  # nix-index-database is enabled globally for each user in modules/config/home-manager.nix
  programs.nix-index.enable = true;
  programs.nix-index.enableZshIntegration = false;
  programs.nix-index-database.comma.enable = true;

  home.persistence."/state".directories = [
    ".local/share/zoxide"
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

    nb = "nix build --no-link --print-out-paths";

    ip = "ip --color";
    tmux = "tmux -2";
    rg = "rg -S";
  };
}
