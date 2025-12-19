{ pkgs, ... }:
{
  home.packages = with pkgs; [
    discord
  ];

  home.persistence."/state".directories = [
    ".config/discord" # Bad Discord! BAD! Saves its state in .config tststs
  ];
}
