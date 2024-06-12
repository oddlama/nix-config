{
  lib,
  pkgs,
  ...
}: {
  programs.waybar = {
    enable = true;
    style = builtins.readFile ./waybar-style.css;
    settings.main = {
      layer = "top";
      position = "bottom";
      height = 28;

      modules-left = [
        "hyprland/workspaces"
        "tray"
        "hyprland/submap"
        "privacy"
      ];
      modules-center = [
        "hyprland/window"
      ];
      modules-right = [
        "custom/scanqr"
        "custom/pickcolor"
        #"custom/screencast"
        #"custom/gpuscreenrecorder"

        #SPACER

        #"brightness"
        "pulseaudio#source"
        "wireplumber"

        "network"
        "bluetooth"

        #"temps"
        "cpu"
        "memory"
        #"battery"

        "custom/notification"
        "clock"
      ];

      "custom/scanqr" = {
        tooltip = false;
        format = "󰐲";
        on-click = lib.getExe pkgs.scripts.screenshot-area-scan-qr;
      };

      "custom/pickcolor" = {
        tooltip = false;
        format = "";
        on-click = "${lib.getExe pkgs.hyprpicker} --autocopy";
      };

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
        exec = "swaync-client -swb";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        on-click-middle = "swaync-client --close-all";
        escape = true;
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
        format-icons = ["" ""];
        on-click = "hyprctl dispatch exec \"[float;pin;move 80% 50%;size 20% 50%;noborder]\" ${lib.getExe pkgs.pwvucontrol}";
        on-click-middle = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 100%";
        on-click-right = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      };

      "pulseaudio#source" = {
        format = "{format_source}";
        format-source = "<tt> {volume}%</tt>";
        format-source-muted = "<tt> {volume}%</tt>";
        on-click = "${lib.getExe pkgs.helvum}";
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
        format = "{:%H:%M}";
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
        format-ethernet = "󰈀  {ipaddr}/{cidr}";
        format-disconnected = "⚠  Disconnected";
        tooltip-format = " {bandwidthUpBytes}\n {bandwidthDownBytes}";
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
}
