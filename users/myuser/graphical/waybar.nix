{
  programs.waybar = {
    enable = true;
    style = builtins.readFile ./waybar-style.css;
    settings.main = {
      layer = "top";
      position = "top";
      height = 30;

      modules-left = ["wlr/workspaces" "wlr/taskbar"];
      modules-center = ["hyprland/window"];
      modules-right = ["network" "clock" "bluetooth" "cpu" "memory" "tray"];

      "wlr/workspaces" = {
        format = "{icon}";
        on-click = "activate";
        format-icons = {
          urgent = "";
        };
        sort-by-number = true;
        all-outputs = true;
      };

      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%A, %B %d, %Y (%R)}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "year";
          mode-mon-col = 3;
          weeks-pos = "right";
          on-scroll = 1;
          on-click-right = "mode";
          format = {
            months = "<span color='#ffead3'><b>{}</b></span>";
            days = "<span color='#ecc6d9'><b>{}</b></span>";
            weeks = "<span color='#99ffdd'><b>W{}</b></span>";
            weekdays = "<span color='#ffcc66'><b>{}</b></span>";
            today = "<span color='#ff6699'><b><u>{}</u></b></span>";
          };
          actions = {
            on-click-right = "mode";
            on-click-forward = "tz_up";
            on-click-backward = "tz_down";
            on-scroll-up = "shift_up";
            on-scroll-down = "shift_down";
          };
        };
      };

      network = {
        interval = 5;
        format-ethernet = " {ipaddr}/{cidr}"; # Icon: ethernet
        format-disconnected = "⚠  Disconnected";
        tooltip-format = ": {bandwidthDownBytes} : {bandwidthUpBytes}";
      };

      bluetooth = {
        format = "  {status} ";
        format-connected = " {device_alias}";
        format-connected-battery = " {device_alias} {device_battery_percentage}%";
        tooltip-format = "{controller_alias}\t{controller_address}\n\n{num_connections} connected";
        tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
        tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
        tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t{device_battery_percentage}%";
      };

      memory = {
        interval = 5;
        format = "  {}%";
        states = {
          warning = 70;
          critical = 90;
        };
      };

      cpu = {
        interval = 5;
        format = " {icon0} {icon1} {icon2} {icon3} {icon4} {icon5} {icon6} {icon7}";
        tooltip-format = "{usage}";
        format-icons = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
      };

      tray = {
        icon-size = 21;
        spacing = 10;
      };
    };
  };
}
