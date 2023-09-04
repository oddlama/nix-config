{pkgs, ...}: {
  imports = [
    ./kitty.nix
    ./sway.nix
  ];

  home = {
    packages = with pkgs; [
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

    shellAliases = {
      p = "cd ~/projects";
      zf = "zathura --fork";
    };

    persistence."/persist".directories = [
      ".config/discord" # Bad Discord! BAD! Saves its state in .config tststs
      ".config/Signal" # L take, electron.
      "projects"
    ];

    persistence."/state".directories = [
      "Downloads"
    ];
  };
}
