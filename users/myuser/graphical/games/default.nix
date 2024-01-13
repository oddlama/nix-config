{
  imports = [
    ./minecraft.nix
    ./bottles.nix
  ];

  home.persistence."/persist".directories = [
    ".local/share/pobfrontend" # Path of Building
  ];
}
