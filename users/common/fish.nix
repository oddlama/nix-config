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
        set -g fish_autosuggestion_enabled 0
        set -g FZF_COMPLETE 2
      '')
      (mkAfter ''
        bind \cr _atuin_search
      '')
    ];
    plugins = [
      {
        name = "fzf";
        src = pkgs.fetchFromGitHub {
          owner = "jethrokuan";
          repo = "fzf";
          rev = "479fa67d7439b23095e01b64987ae79a91a4e283";
          sha256 = "0k6l21j192hrhy95092dm8029p52aakvzis7jiw48wnbckyidi6v";
        };
      }
    ];
  };
}
