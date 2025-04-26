{
  lib,
  pkgs,
  ...
}:
{
  # Needed in path for zsh-histdb
  home.packages = [ pkgs.sqlite-interactive ];

  programs.zsh = {
    enable = true;
    envExtra = ''
      umask 077
    '';
    dotDir = ".config/zsh";
    history = {
      path = "\${XDG_DATA_HOME-$HOME/.local/share}/zsh/history";
      save = 1000500;
      size = 1000000;
    };
    initContent = lib.mkMerge [
      (lib.mkBefore ''
        HISTDB_FILE=''${XDG_DATA_HOME-$HOME/.local/share}/zsh/history.db

        # Do this early so fast-syntax-highlighting can wrap and override this
        if autoload history-search-end; then
          zle -N history-beginning-search-backward-end history-search-end
          zle -N history-beginning-search-forward-end  history-search-end
        fi
      '')
      (lib.readFile ./zshrc)
    ];
    plugins = [
      {
        # Must be before plugins that wrap widgets, such as zsh-autosuggestions or fast-syntax-highlighting
        name = "fzf-tab";
        src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
      }
      {
        name = "fast-syntax-highlighting";
        src = "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions";
      }
      {
        name = "zsh-autosuggestions";
        file = "zsh-autosuggestions.zsh";
        src = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
      }
      {
        name = "zsh-histdb";
        src = pkgs.fetchFromGitHub {
          owner = "larkery";
          repo = "zsh-histdb";
          rev = "30797f0c50c31c8d8de32386970c5d480e5ab35d";
          hash = "sha256-PQIFF8kz+baqmZWiSr+wc4EleZ/KD8Y+lxW2NT35/bg=";
        };
      }
      {
        name = "zsh-histdb-skim";
        src = "${pkgs.zsh-histdb-skim}/share/zsh-histdb-skim";
      }
    ];
  };

  home.persistence."/persist".directories = [
    ".local/share/zsh" # History
  ];
}
