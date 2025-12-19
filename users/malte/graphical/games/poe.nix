{ pkgs, ... }:
{
  home.persistence."/state".directories = [
    ".config/awakened-poe-trade"
  ];

  home.persistence."/persist".directories = [
    ".local/share/pobfrontend"
  ];

  home.packages = [
    pkgs.rusty-path-of-building
  ];
}
