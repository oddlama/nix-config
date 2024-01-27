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
      unzip
      zip
      wget
      usbutils
      pciutils
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
