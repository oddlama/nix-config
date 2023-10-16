{
  pkgs,
  lib,
  minimal,
  ...
}:
lib.optionalAttrs (!minimal) {
  home = {
    packages = with pkgs; [
      bandwhich
      btop
      delta
      fd
      file
      hexyl
      killall
      ncdu
      neofetch
      nvd
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
