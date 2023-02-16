{
  lib,
  pkgs,
  ...
}:
with lib; {
  programs.zsh = {
    enable = true;
    envExtra = ''
      umask 077
    '';
    dotDir = ".config/zsh";
    history = {
      path = "/dev/null";
      save = 0;
      size = 0;
    };
    initExtra = mkMerge [
      (mkBefore ''
        unset HISTFILE
      '')
      (mkAfter (readFile ./zshrc))
    ];
    plugins = [
      {
        # Must be before plugins that wrap widgets, such as zsh-autosuggestions or fast-syntax-highlighting
        name = "fzf-tab";
        src = pkgs.fetchFromGitHub {
          owner = "Aloxaf";
          repo = "fzf-tab";
          rev = "69024c27738138d6767ea7246841fdfc6ce0d0eb";
          sha256 = "07wwcplyb2mw10ia9y510iwfhaijnsdcb8yv2y3ladhnxjd6mpf8";
        };
      }
      {
        name = "fast-syntax-highlighting";
        src = pkgs.fetchFromGitHub {
          owner = "zdharma-continuum";
          repo = "fast-syntax-highlighting";
          rev = "7c390ee3bfa8069b8519582399e0a67444e6ea61";
          sha256 = "0gh4is2yzwiky79bs8b5zhjq9khksrmwlaf13hk3mhvpgs8n1fn0";
        };
      }
      {
        name = "zsh-autosuggestions";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-autosuggestions";
          rev = "a411ef3e0992d4839f0732ebeb9823024afaaaa8";
          sha256 = "1g3pij5qn2j7v7jjac2a63lxd97mcsgw6xq6k5p7835q9fjiid98";
        };
      }
    ];
  };
}
