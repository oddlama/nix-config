{ config, ... }:
{
  home.persistence."/state".files = [
    ".cache/fuzzel"
  ];

  programs.fuzzel = {
    enable = true;
    settings.colors = with config.lib.colors.hex; {
      background = "${base00}ff";
      text = "${base05}ff";
      placeholder = "${base03}ff";
      prompt = "${base05}ff";
      input = "${base05}ff";
      match = "${base0A}ff";
      selection = "${base03}ff";
      selection-text = "${base05}ff";
      selection-match = "${base0A}ff";
      counter = "${base06}ff";
      border = "${base0D}ff";
    };
    settings.main = {
      font = "Segoe UI:size=20";
      launch-prefix = "uwsm app --";
    };
  };
}
