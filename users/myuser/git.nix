{
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    git-filter-repo
    git-fuzzy
  ];

  programs.gitui.enable = true;
  programs.git = {
    enable = true;
    difftastic = {
      enable = true;
      background = "dark";
    };
    lfs.enable = lib.mkDefault false;
    extraConfig = {
      core.pager = "${pkgs.delta}/bin/delta";
      delta = {
        hyperlinks = true;
        keep-plus-minus-markers = true;
        line-numbers = true;
        navigate = true;
        side-by-side = true;
        syntax-theme = "TwoDark";
        tabs = 4;
      };
      fuzzy = {
        bat-theme = "TwoDark";
        # TODO fuzzy is bad, it hardcodes diff | pager exec style.
        # This needs to be patched so we can use difft. alternative:
        # don't use a pager in fuzzy and somehow make difft width available to the main git diff command
        #preferred-pager = let
        #  wrapper = pkgs.writeShellScript "difft-for-fuzzy" ''
        #    ${pkgs.difftastic}/bin/difft --color=always --width "$1"
        #  '');
        #in "${wrapper} __WIDTH__";
        status-directory-preview-command = "ls -lahF --group-directories-first --show-control-chars --quoting-style=escape --color=always";
      };
      difftool.prompt = true;
      init.defaultBranch = "main";
      merge.conflictstyle = "diff3";
      mergetool.prompt = true;
      commit.gpgsign = true;
      pull.rebase = true;
      rebase.autostash = true;
      push.autoSetupRemote = true;
    };
    aliases = {
      unstash = "stash pop";
      s = "status";
      tags = "tag -l";
      t = "tag -s -m ''";
      fixup = ''!f() { TARGET=$(git rev-parse "$1"); git commit --fixup=$TARGET ''${@:2} && EDITOR=true git rebase -i --gpg-sign --autostash --autosquash $TARGET^; }; f'';
      # An alias that uses the previous commit message by default.
      # Useful when you mess up entering the signing password and git aborts.
      commit-reuse-message = ''!git commit --edit --file "$(git rev-parse --git-dir)"/COMMIT_EDITMSG'';
    };
  };

  home.shellAliases = {
    g = "gitui";
    ga = "git add";
    gc = "git commit -v -S";
    gca = "git commit -v -S --amend";
    gcl = "git clone";
    gcr = "git commit-reuse-message -v -S";
    gf = lib.getExe (
      pkgs.writeShellApplication {
        name = "git-fixup-fzf";
        runtimeInputs = [
          pkgs.fzf
          pkgs.gnugrep
        ];
        text = ''
          if ! commit=$(set +o pipefail; git log --graph --color=always --format="%C(auto)%h%d %s %C(reset)%C(bold)%cr" "$@" \
            | fzf --ansi --multi --no-sort --reverse --print-query --expect=ctrl-d --toggle-sort=\`); then
            echo aborted
            exit 0
          fi

          sha=$(grep -o '^[^a-z0-9]*[a-z0-9]\{7\}[a-z0-9]*' <<< "$commit" | grep -o '[a-z0-9]\{7\}[a-z0-9]*')
          if [[ -z "$sha" ]]; then
            echo "Found no checksum for selected commit. Aborting."
            exit 1
          fi

          git fixup "$sha" "$@"
        '';
      }
    );
    gp = "git push";
    gpf = "git push --force";
    gs = "git s";
  };
}
