{
  lib,
  pkgs,
  ...
}: {
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
    initExtra = lib.readFile ./zshrc;
    plugins = [
      {
        # Must be before plugins that wrap widgets, such as zsh-autosuggestions or fast-syntax-highlighting
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
      }
      {
        name = "fast-syntax-highlighting";
        src = pkgs.zsh-fast-syntax-highlighting;
      }
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
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
        src = pkgs.fetchFromGitHub {
          owner = "m42e";
          repo = "zsh-histdb-skim";
          rev = "3af19b6ec38b93c85bb82a80a69bec8b0e050cc5";
          hash = "sha256-lJ2kpIXPHE8qP0EBnLuyvatWMtepBobNAC09e7itGas=";
        };
      }
    ];
  };

  home.persistence."/persist".directories = [
    ".local/share/zsh" # History
  ];
}
