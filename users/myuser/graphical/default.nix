{pkgs, ...}: {
  imports = [
    ./kitty.nix
    ./sway.nix
  ];

  home.packages = with pkgs; [
    discord
    firefox
    thunderbird
    signal-desktop
    chromium
    zathura
    feh
  ];

  # TODO VP9 hardware video decoding blocklisted
  # TODO gpg switch to sk

  home.shellAliases = {
    p = "cd ~/projects";
    zf = "zathura --fork";
  };
}
