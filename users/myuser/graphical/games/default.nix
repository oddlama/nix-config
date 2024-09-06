{
  imports = [
    ./minecraft.nix
    ./bottles.nix
    ./poe.nix
  ];

  programs.mangohud.enable = true;
}
