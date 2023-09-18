{pkgs, ...}: {
  home = {
    packages = with pkgs; [
      bandwhich
      btop
      fd
      file
      hexyl
      killall
      ncdu
      neofetch
      rage
      rclone
      ripgrep
      rnr
      rsync
      sd
      tree
      wget
    ];
  };

  programs = {
    bat = {
      enable = true;
      config.theme = "TwoDark";
    };
    fzf.enable = true;
    gpg.enable = true;
  };
}
