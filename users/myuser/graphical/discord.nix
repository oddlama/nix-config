{pkgs, ...}: {
  home.packages = with pkgs; [
    discord
    webcord
  ];

  home.persistence."/state".directories = [
    ".config/discord" # Bad Discord! BAD! Saves its state in .config tststs
    ".config/WebCord" # You too, WebCord!
  ];
}
