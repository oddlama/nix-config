{
  lib,
  pkgs,
  ...
}:
with lib; {
  # FIXME: ctrl-del not working
  # FIXME: DEL also deletes to the left :(
  # FIXME: ignore certain history entries (" .*", ...)
  # FIXME: after tab give space
  # FIXME: fzf tab let multi
  programs.fish = {
    enable = true;
    interactiveShellInit = mkMerge [
      (mkBefore ''
        set -g ATUIN_NOBIND true
        set -g fish_greeting
      '')
      (mkAfter ''
        bind \cr _atuin_search
        atuin gen-completions --shell fish | source

        bind \e\[A history-prefix-search-backward
        bind \e\[B history-prefix-search-forward
      '')
    ];
    plugins = [
      {
        name = "fzf";
        src = pkgs.fetchFromGitHub {
          owner = "oddlama";
          repo = "fzf.fish";
          rev = "63c8f8e65761295da51029c5b6c9e601571837a1";
          sha256 = "036n50zr9kyg6ad408zn7wq2vpfwhmnfwab465km4dk60ywmrlcb";
        };
      }
    ];
  };
}
