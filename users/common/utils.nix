{pkgs, ...}: {
  home = {
    packages = with pkgs; [
      bandwhich
      btop
      fd
      file
      hexyl
      neofetch
      rage
      rclone
      ripgrep
      rnr
      rsync
      sd
      tree
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
