{
  lib,
  pkgs,
  ...
}:
let
  swww-update-wallpaper = pkgs.writeShellApplication {
    name = "swww-update-wallpaper";
    runtimeInputs = [
      pkgs.swww
    ];
    text = ''
      FILES=("$HOME/.local/share/wallpapers/"*)
      TYPES=("wipe" "any")
      ANGLES=(0 15 30 45 60 75 90 105 120 135 150 165 180 195 210 225 240 255 270 285 300 315 330 345)

      swww img "''${FILES[RANDOM%''${#FILES[@]}]}" \
        --transition-type "''${TYPES[RANDOM%''${#TYPES[@]}]}" \
        --transition-angle "''${ANGLES[RANDOM%''${#ANGLES[@]}]}" \
        --transition-fps 144 \
        --transition-duration 1.5
    '';
  };
in
{
  systemd.user = {
    services = {
      swww = {
        Install.WantedBy = [ "graphical-session.target" ];
        Unit = {
          Description = "Wayland wallpaper daemon";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.swww}/bin/swww-daemon";
          Restart = "on-failure";
        };
      };
      swww-update-wallpaper = {
        Install.WantedBy = [ "default.target" ];
        Unit.Description = "Update the wallpaper";
        Service = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = "2m";
          ExecStart = lib.getExe swww-update-wallpaper;
        };
      };
    };
    timers.swww-update-wallpaper = {
      Install.WantedBy = [ "timers.target" ];
      Unit.Description = "Periodically switch to a new wallpaper";
      Timer.OnCalendar = "*:0/5"; # Every 5 minutes
    };
  };
}
