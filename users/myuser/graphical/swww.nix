{pkgs, ...}: {
  systemd.user = {
    services = {
      swww = {
        Unit = {
          Description = "Wayland wallpaper daemon";
          PartOf = ["graphical-session.target"];
        };
        Service = {
          ExecStart = "${pkgs.swww}/bin/swww-daemon";
          Restart = "on-failure";
        };
        Install.WantedBy = ["graphical-session.target"];
      };
      #swww-random = {
      #  Unit = {
      #    Description = "switch random wallpaper powered by swww";
      #  };
      #  Service = {
      #    Type = "oneshot";
      #    ExecStart = "${pkgs.swww-switch}/bin/swww-switch random";
      #  };
      #  Install = {
      #    WantedBy = ["default.target"];
      #  };
      #};
    };
    #timers.swww-random = {
    #  Unit = {
    #    Description = "switch random wallpaper powered by swww timer";
    #  };
    #  Timer = {
    #    OnUnitActiveSec = "60min";
    #    OnBootSec = "60min";
    #  };
    #  Install = {WantedBy = ["timers.target"];};
    #};
  };
}
