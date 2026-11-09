{
  home.persistence."/state".directories = [
    ".cache/noctalia"
    # Settings changed in the UI are stored in settings.toml here, on top of the declarative config.toml
    ".local/state/noctalia"
  ];

  programs.niri.settings = {
    layer-rules = [
      {
        matches = [ { namespace = "^noctalia-wallpaper"; } ];
        place-within-backdrop = true;
      }
    ];

    window-rules = [
      {
        matches = [ { app-id = "^dev\\.noctalia\\.Noctalia$"; } ];
        open-floating = true;
        default-column-width.fixed = 1080;
        default-window-height.fixed = 920;
      }
    ];

    layout = {
      background-color = "transparent";
    };

    overview.workspace-shadow.enable = false;
    debug.honor-xdg-activation-with-invalid-serial = [ ];
  };

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    # Settings changed in the UI land in ~/.local/state/noctalia/settings.toml and
    # override these. Move them here and then delete that file.
    settings = {
      config_version = 15;

      audio.enable_overdrive = true;

      bar.default = {
        position = "bottom";
        padding = 10;
        margin_ends = 0;
        panel_overlap = 2;
        start = [
          "control-center"
          "session"
          "wallpaper"
          "audio_visualizer"
          "media"
          "spacer_4"
          "cpu"
          "ram"
          "temp"
        ];
        center = [
          "privacy"
          "spacer_6"
          "tray"
          "spacer_5"
          "workspaces"
          "spacer_7"
          "network_rx"
          "network_tx"
        ];
        end = [
          "network"
          "bluetooth"
          "brightness"
          "spacer_2"
          "input_volume"
          "output_volume"
          "spacer_3"
          "battery"
          "notifications"
          "clock"
        ];
      };

      control_center.calendar.show_week_numbers = true;

      shell = {
        clipboard_enabled = false;
        font_family = "JetBrains Mono";
        offline_mode = true;
        screen_time_enabled = true;
        panel = {
          open_near_click_control_center = true;
          open_near_click_session = true;
          open_near_click_wallpaper = true;
          session_placement = "floating";
        };
      };

      theme = {
        builtin = "Ayu";
        pure_black_dark = true;
        templates = {
          enable_builtin_templates = false;
          enable_community_templates = false;
        };
      };

      wallpaper.automation = {
        enabled = true;
        interval_seconds = 600;
      };

      widget = {
        control-center = {
          color = "tertiary";
          glyph = "snowflake";
        };
        cpu = {
          label_min_width = 32;
          visualization = "graph";
        };
        media.hide_when_no_media = true;
        network.vpn_status = "both";
        network_rx = {
          icon_color = "secondary";
          label_min_width = 50;
          network_speed_compact = true;
          visualization = "graph";
        };
        network_tx = {
          icon_color = "tertiary";
          label_min_width = 50;
          network_speed_compact = true;
          visualization = "graph";
        };
        privacy.icon_spacing = 8;
        ram = {
          label_min_width = 84;
          visualization = "graph";
        };
        workspaces = {
          anchor = true;
          font_weight = 700;
          label_source = "name";
          labels_only_when_occupied = true;
          max_label_chars = 20;
          actions = {
            scroll_down = "none";
            scroll_up = "none";
          };
        };

        spacer_2.type = "spacer";
        spacer_3.type = "spacer";
        spacer_4 = {
          type = "spacer";
          length = 32;
        };
        spacer_5.type = "spacer";
        spacer_6.type = "spacer";
        spacer_7.type = "spacer";
      };
    };
  };
}
