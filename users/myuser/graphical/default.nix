{pkgs, ...}: {
  imports = [
    ./kitty.nix
    ./sway.nix
  ];

  # TODO own file
  programs.firefox.enable = true;
  home.sessionVariables = {
    MOZ_WEBRENDER = 1;
  };

  home = {
    packages = with pkgs; [
      discord
      thunderbird
      signal-desktop
      chromium
      zathura
      feh
    ];

    # TODO VP9 hardware video decoding blocklisted
    # TODO gpg switch to sk
    # TODO some font icons not showing
    # TODO seogue ui

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
