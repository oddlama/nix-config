{pkgs, ...}: {
  home.persistence."/state".directories = [
    ".config/awakened-poe-trade"
  ];

  home.persistence."/persist".directories = [
    ".local/share/pobfrontend"
  ];

  home.packages = [
    pkgs.awakened-poe-trade
    pkgs.path-of-building
  ];
}
