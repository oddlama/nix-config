{pkgs, ...}: {
  home = {
    packages = with pkgs; [
      bandwhich
      btop
      fd
      file
      neofetch
      rclone
      ripgrep
      rnr
      rsync
      sd
      tree
      rage
    ];
  };

  programs = {
    bat = {
      enable = true;
      config.theme = "base16";
    };
    fzf.enable = true;
    gpg.enable = true;
  };
}
