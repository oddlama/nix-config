{ pkgs, ... }:
{
  home.packages = with pkgs; [
    signal-desktop
  ];

  home.persistence."/persist".directories = [
    ".config/Signal" # L take, electron.
  ];
}
