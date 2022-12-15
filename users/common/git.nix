{
  lib,
  pkgs,
  ...
}: {
  programs.gitui.enable = true;
  programs.git = {
    enable = true;
    difftastic.enable = true;
    lfs.enable = lib.mkDefault false;
    extraConfig = {
      #diff = {
      #  colorMoved = "default";
      #  age.textconv = "${pkgs.rage}/bin/rage -i ~/.ssh/username --decrypt";
      #};
      difftool.prompt = true;
      init.defaultBranch = "main";
      merge.conflictstyle = "diff3";
      mergetool.prompt = true;
    };
    aliases = {
      unstash = "stash pop";
      s = status;
      tags = "tag -l";
      t = "tag -s -m ''";
      ci = "commit -v -S";
      cam = "commit -v -S --amend";
    };
  };

  home.shellAliases = rec {
    g = "gitui";
    gs = "git status";
    ga = "git add";
    gc = "git commit -v -S";
    gca = "${gci} --amend";
  };
}
