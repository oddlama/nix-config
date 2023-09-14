{pkgs, ...}: {
  # XXX: to enable dark mode, no idea why it isn't detected by default.
  # dconf write /com/usebottles/bottles/dark-theme true

  home.packages = with pkgs; [
    bottles
    winetricks
    wineWowPackages.fonts
    wineWowPackages.stagingFull
  ];

  home.persistence."/state".directories = [
    ".local/share/bottles"
  ];

  home.persistence."/persist".directories = [
    ".local/share/bottles/bottles/League-of-Legends/drive_c/users"
    ".local/share/bottles/bottles/Gaming/drive_c/users"
  ];
}
