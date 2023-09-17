{lib, ...}: {
  # TODO use git-fuzzy.
  # TODO integrate git-fuzzy and difft
  programs.gitui.enable = true;
  programs.git = {
    enable = true;
    difftastic.enable = true;
    lfs.enable = lib.mkDefault false;
    extraConfig = {
      difftool.prompt = true;
      init.defaultBranch = "main";
      merge.conflictstyle = "diff3";
      mergetool.prompt = true;
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
    aliases = {
      unstash = "stash pop";
      s = "status";
      tags = "tag -l";
      t = "tag -s -m ''";
      ci = "commit -v -S";
      cam = "commit -v -S --amend";
      fixup = ''!f() { TARGET=$(git rev-parse "$1"); git commit --fixup=$TARGET ''${@:2} && EDITOR=true git rebase -i --gpg-sign --autostash --autosquash $TARGET^; }; f'';
      commit-reuse-message = ''!git commit --edit --file "$(git rev-parse --git-dir)"/COMMIT_EDITMSG'';
      cir = "commit-reuse-message -v -S";
    };
  };

  home.shellAliases = rec {
    g = "gitui";
    ga = "git add";
    gc = "git ci";
    gca = "git ci --amend";
    gcl = "git clone";
    gcr = "git cir";
    gs = "git s";
  };
}
