{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkOption
    mkEnableOption
    mkPackageOption
    literalExpression
    mkIf
    types
    ;

  settingsFormat = pkgs.formats.yaml {};
  cfg = config.services.deadd-notification-center;
in {
  options.services.deadd-notification-center = {
    enable = mkEnableOption "deadd notification center";
    package = mkPackageOption pkgs "deadd-notification-center" {};

    settings = mkOption {
      default = {};
      type = types.submodule {
        freeformType = settingsFormat.type;
      };
      description = ''
        Settings for the notification center.
        Refer to https://github.com/phuhl/linux_notification_center#configuration for available options.
      '';
      example = literalExpression ''
        {
          notification-center = {
            marginTop = 30;
            width = 500;
          };
        }
      '';
    };

    style = mkOption {
      type = types.lines;
      description = "CSS styling for notifications.";
    };
  };

  config = mkIf cfg.enable {
    xdg.configFile."deadd/deadd.yml".source = settingsFormat.generate "deadd.yml" cfg.settings;
    xdg.configFile."deadd/deadd.css".text = cfg.style;

    systemd.user.services.deadd-notification-center = {
      Install.WantedBy = ["graphical-session.target"];
      Unit = {
        Description = "Deadd Notification Center";
        After = ["graphical-session-pre.target"];
        PartOf = ["graphical-session.target"];
        X-Restart-Triggers = [
          config.xdg.configFile."deadd/deadd.yml".source
          config.xdg.configFile."deadd/deadd.css".source
        ];
      };
      Service = {
        Type = "dbus";
        BusName = "org.freedesktop.Notifications";
        ExecStart = "${cfg.package}/bin/deadd-notification-center";
        Restart = "always";
        RestartSec = "1sec";
      };
    };
  };
}
