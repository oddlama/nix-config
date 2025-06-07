{
  lib,
  pkgs,
  ...
}:
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ./waybar-style.css;
    settings.main = {
      layer = "top";
      position = "bottom";
      height = 28;

      modules-left = [
        "hyprland/workspaces"
        "tray"
        "hyprland/submap"
        "privacy"
        #"custom/whisper_overlay"
      ];
      modules-center = [
        "hyprland/window"
      ];
      modules-right = [
        "custom/scan_qr"
        "custom/pick_color"
        "custom/cycle_wallpaper"
        #"custom/screencast"
        #"custom/gpuscreenrecorder"

        #SPACER

        #"brightness"
        "pulseaudio#source"
        "wireplumber"

        "network"
        "bluetooth"

        #"temperature"
        "cpu"
        "memory"
        "battery"

        "custom/notification"
        "clock"
      ];

      "custom/scan_qr" = {
        tooltip = true;
        tooltip-format = "Scan QR Code";
        format = "󰐲";
        on-click = lib.getExe pkgs.scripts.screenshot-area-scan-qr;
      };

      "custom/pick_color" = {
        tooltip = true;
        tooltip-format = "Pick color";
        format = "";
        on-click = "${lib.getExe pkgs.hyprpicker} --autocopy";
      };
      #
      # "custom/cycle_wallpaper" = {
      #   format = " ";
      #   tooltip = true;
      #   tooltip-format = "Change wallpaper";
      #   on-click = "systemctl --user start swww-update-wallpaper";
      # };

      "custom/notification" = {
        tooltip = false;
        format = "{icon} {}";
        format-icons = {
          notification = "<span foreground='red'><sup></sup></span>";
          none = "";
          dnd-notification = "<span foreground='red'><sup></sup></span>";
          dnd-none = "";
          inhibited-notification = "<span foreground='red'><sup></sup></span>";
          inhibited-none = "";
          dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>";
          dnd-inhibited-none = "";
        };
        return-type = "json";
        exec = "${pkgs.swaynotificationcenter}/bin/swaync-client -swb";
        on-click = "${pkgs.swaynotificationcenter}/bin/swaync-client -t -sw";
        on-click-right = "${pkgs.swaynotificationcenter}/bin/swaync-client -d -sw";
        on-click-middle = "${pkgs.swaynotificationcenter}/bin/swaync-client --close-all";
        escape = true;
      };

      battery = {
        interval = 2;
        format = "{icon}  {capacity}%";
        format-icons = [
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
        ];
        states = {
          warning = 25;
          critical = 15;
        };
      };

      privacy = {
        icon-spacing = 4;
        icon-size = 18;
        transition-duration = 250;
        modules = [
          {
            type = "screenshare";
            tooltip = true;
            tooltip-icon-size = 24;
          }
          {
            type = "audio-out";
            tooltip = true;
            tooltip-icon-size = 24;
          }
          {
            type = "audio-in";
            tooltip = true;
            tooltip-icon-size = 24;
          }
        ];
      };

      wireplumber = {
        format = "<tt>{icon} {volume}%</tt>";
        format-muted = "<tt> {volume}%</tt>";
        format-icons = [
          ""
          ""
        ];
        on-click = "${pkgs.hyprland}/bin/hyprctl dispatch exec \"[float;pin;move 80% 50%;size 20% 50%;noborder]\" ${lib.getExe pkgs.pwvucontrol}";
        on-click-middle = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 100%";
        on-click-right = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };

      "pulseaudio#source" = {
        format = "{format_source}";
        format-source = "<tt> {volume}%</tt>";
        format-source-muted = "<tt> {volume}%</tt>";
        on-click = "${pkgs.hyprland}/bin/hyprctl dispatch exec \"[float]\" ${lib.getExe pkgs.helvum}";
        on-click-middle = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 100%";
        on-click-right = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        on-scroll-up = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 1%+";
        on-scroll-down = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 1%-";
      };

      "hyprland/workspaces" = {
        format = "{icon}";
        format-icons.urgent = "";
        all-outputs = false;
        sort-by = "id";
      };

      clock = {
        interval = 10;
        format = "{:%H:%M:%S}";
        format-alt = "{:%A, %B %d, %Y (%R)}";
        tooltip-format = "<tt><span size='16pt' font='JetBrains Mono'>{calendar}</span></tt>";
        calendar = {
          mode = "year";
          mode-mon-col = 4;
          weeks-pos = "right";
          on-scroll = 1;
          on-click-right = "mode";
          format = {
            months = "<span color='#ffead3'><b>{}</b></span>";
            days = "<span color='#ecc6d9'><b>{}</b></span>";
            weeks = "<span color='#99ffdd'><b>W{}</b></span>";
            weekdays = "<span color='#ffcc66'><b>{}</b></span>";
            today = "<span bgcolor='#ff6699' color='#000000'><b><u>{}</u></b></span>";
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
        format-ethernet = "󰈀  {ipaddr}/{cidr} <span color='#ffead3'>↓ {bandwidthDownBytes}</span> <span color='#ecc6d9'>↑ {bandwidthUpBytes}</span>";
        format-wifi = "  {signalStrength}% {essid} {ipaddr}/{cidr} <span color='#ffead3'>↓ {bandwidthDownBytes}</span> <span color='#ecc6d9'>↑ {bandwidthUpBytes}</span>";
        format-disconnected = "⚠ Disconnected";
        tooltip-format = "↑ {bandwidthUpBytes}\n↓ {bandwidthDownBytes}";
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
        format = "  {percentage}%";
        states = {
          warning = 70;
          critical = 90;
        };
      };

      cpu = {
        interval = 5;
        format = "  {usage}%";
        tooltip-format = "{usage}";
      };

      tray = {
        icon-size = 21;
        spacing = 10;
      };
    };
  };

  systemd.user.services.waybar = {
    Unit.After = [ "graphical-session.target" ];
    Service.Slice = [ "app-graphical.slice" ];
  };
}
