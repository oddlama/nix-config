{
  imports = [
    ./minecraft.nix
    ./bottles.nix
    ./poe.nix
  ];

  home.persistence."/persist".directories = [
    ".local/share/Terraria"
  ];

  programs.mangohud.enable = true;
}
