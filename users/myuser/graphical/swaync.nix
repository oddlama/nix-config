{
  config,
  lib,
  ...
}: {
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";

      layer = "overlay";
      layer-shell = true;
      cssPriority = "application";

      control-center-layer = "top";
      control-center-width = 800;
      control-center-height = 1600;
      control-center-margin-top = 0;
      control-center-margin-bottom = 0;
      control-center-margin-right = 0;
      control-center-margin-left = 0;

      notification-window-width = 800;
      notification-2fa-action = true;
      notification-inline-replies = false;
      notification-icon-size = 64;
      notification-body-image-height = 100;
      notification-body-image-width = 200;

      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 100;

      widgets = [
        "inhibitors"
        "dnd"
        "mpris"
        "notifications"
      ];

      widget-config = {
        inhibitors = {
          text = "Inhibitors";
          button-text = "Clear All";
          clear-all-button = true;
        };
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear All";
        };
        dnd = {
          text = "Do Not Disturb";
        };
        label = {
          max-lines = 5;
          text = "Label Text";
        };
        mpris = {
          image-size = 96;
          blur = true;
        };
      };
    };
    style =
      lib.concatLines (
        map (c: "@define-color ${c} ${config.lib.stylix.colors.withHashtag.${c}};") [
          "base00"
          "base01"
          "base02"
          "base03"
          "base04"
          "base05"
          "base06"
          "base07"
          "base08"
          "base09"
          "base0A"
          "base0B"
          "base0C"
          "base0D"
          "base0E"
          "base0F"
        ]
      )
      + (builtins.readFile ./swaync-style.css);
  };
}
