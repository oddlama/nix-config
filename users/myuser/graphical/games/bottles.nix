{pkgs, ...}: {
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
