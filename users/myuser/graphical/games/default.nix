{pkgs, ...}: {
  imports = [
    ./minecraft.nix
    ./bottles.nix
  ];

  home.persistence."/persist".directories = [
    ".local/share/pobfrontend" # Path of Building
  ];

  home.packages = [
    pkgs.awakened-poe-trade
  ];
}
