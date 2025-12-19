{
  lib,
  pkgs,
  inputs,
  config,
  nixosConfig,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    getExe
    ;
in
{
  imports = [
    inputs.niri.homeModules.niri
  ];

  home.packages = [
    pkgs.nirius
  ];

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config.niri = {
      default = [
        "gnome"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Access" = "gtk";
      "org.freedesktop.impl.portal.Notification" = "gtk";
      "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
      "org.freedesktop.impl.portal.FileChooser" = "gtk";
      "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
    };
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;

    settings = mkMerge [
      {
        xwayland-satellite.path = getExe pkgs.xwayland-satellite-stable;

        environment = {
          "QT_QPA_PLATFORM" = "wayland";
          "XDG_SESSION_TYPE" = "wayland";
          "NIXOS_OZONE_WL" = "1";
          "MOZ_ENABLE_WAYLAND" = "1";
          "MOZ_WEBRENDER" = "1";
          "_JAVA_AWT_WM_NONREPARENTING" = "1";
          "QT_WAYLAND_DISABLE_WINDOWDECORATION" = "1";
          "GDK_BACKEND" = "wayland";
        };

        prefer-no-csd = true;
        screenshot-path = "~/Pictures/screenshots/%Y-%m-%dT%H:%M:%S%:z.png";
        hotkey-overlay.skip-at-startup = true;

        input = {
          keyboard = {
            xkb = {
              layout = "de";
              variant = "nodeadkeys";
            };

            repeat-delay = 235;
            repeat-rate = 60;
            numlock = true;
          };

          touchpad = {
            tap = true;
            dwt = true;
            dwtp = true;
            natural-scroll = false;
            accel-profile = "flat";
          };

          mouse = {
            accel-speed = 0.0;
            accel-profile = "flat";
          };

          power-key-handling.enable = false;
          workspace-auto-back-and-forth = true;
        };

        gestures.hot-corners.enable = false;
        debug.honor-xdg-activation-with-invalid-serial = true;

        binds = with config.lib.niri.actions; {
          "Mod+t".action = spawn "kitty";
          "Mod+c".action = spawn "${getExe pkgs.scripts.clone-term}";
          "Mod+b".action = spawn "firefox";
          "Menu".action = spawn "fuzzel";
          "Mod+asciicircum".action = spawn "fuzzel";
          "Mod+Alt+l".action = spawn "systemctl suspend";

          XF86AudioRaiseVolume = {
            action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+";
            allow-when-locked = true;
          };
          XF86AudioLowerVolume = {
            action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-";
            allow-when-locked = true;
          };
          XF86AudioMute = {
            action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
            allow-when-locked = true;
          };
          XF86AudioMicMute = {
            action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle";
            allow-when-locked = true;
          };

          "Mod+q".action = close-window;
          "Mod+Return".action = fullscreen-window;
          "Mod+f".action = toggle-window-floating;
          "Mod+Ctrl+f".action = switch-focus-between-floating-and-tiling;

          "Mod+left".action = focus-column-left;
          "Mod+right".action = focus-column-right;
          "Mod+up".action = focus-window-or-workspace-up;
          "Mod+down".action = focus-window-or-workspace-down;

          "Mod+Shift+left".action = move-column-left;
          "Mod+Shift+right".action = move-column-right;
          "Mod+Shift+up".action = move-window-up;
          "Mod+Shift+down".action = move-window-down;

          "Mod+Ctrl+n".action = focus-monitor-left;
          "Mod+Ctrl+r".action = focus-monitor-down;
          "Mod+Ctrl+l".action = focus-monitor-up;
          "Mod+Ctrl+s".action = focus-monitor-right;

          "Mod+Shift+Ctrl+n".action = move-column-to-monitor-left;
          "Mod+Shift+Ctrl+r".action = move-column-to-monitor-down;
          "Mod+Shift+Ctrl+l".action = move-column-to-monitor-up;
          "Mod+Shift+Ctrl+s".action = move-column-to-monitor-right;

          "Mod+h".action = focus-column-first;
          "Mod+Shift+h".action = consume-or-expel-window-left;
          "Mod+m".action = focus-column-last;
          "Mod+Shift+m".action = consume-or-expel-window-right;

          "Mod+Period".action = focus-workspace-down;
          "Mod+Shift+Period".action = move-column-to-workspace-down;
          "Mod+Ctrl+Period".action = move-workspace-down;
          "Mod+comma".action = focus-workspace-up;
          "Mod+Shift+comma".action = move-column-to-workspace-up;
          "Mod+Ctrl+comma".action = move-workspace-up;

          "Mod+WheelScrollDown" = {
            action = focus-workspace-down;
            cooldown-ms = 150;
          };
          "Mod+WheelScrollUp" = {
            action = focus-workspace-up;
            cooldown-ms = 150;
          };
          "Mod+Ctrl+WheelScrollDown" = {
            action = move-column-to-workspace-down;
            cooldown-ms = 150;
          };
          "Mod+Ctrl+WheelScrollUp" = {
            action = move-column-to-workspace-up;
            cooldown-ms = 150;
          };
          "Mod+WheelScrollRight".action = focus-column-right;
          "Mod+WheelScrollLeft".action = focus-column-left;
          "Mod+Ctrl+WheelScrollRight".action = move-column-right;
          "Mod+Ctrl+WheelScrollLeft".action = move-column-left;
          "Mod+Shift+WheelScrollDown".action = focus-column-right;
          "Mod+Shift+WheelScrollUp".action = focus-column-left;
          "Mod+Ctrl+Shift+WheelScrollDown".action = move-column-right;
          "Mod+Ctrl+Shift+WheelScrollUp".action = move-column-left;

          "Mod+v".action = maximize-column;
          "Mod+Ctrl+v".action = expand-column-to-available-width;
          "Mod+Minus".action = set-column-width "-10%";
          "Mod+Shift+0".action = set-column-width "+10%";

          "Mod+y".action = toggle-column-tabbed-display;

          #"Print".action = screenshot;
          #"Ctrl+Print".action = screenshot-screen {};
          #"Alt+Print".action = screenshot-window;

          "Mod+Escape" = {
            action = toggle-keyboard-shortcuts-inhibit;
            allow-inhibiting = false;
          };

          # The quit action will show a confirmation dialog to avoid accidental exits.
          "Mod+Ctrl+Shift+q".action = quit;
          # Powers off the monitors. To turn them back on, do any input like
          # moving the mouse or pressing any other key.
          "Mod+Shift+p".action = power-off-monitors;
        };

        window-rules = [
          {
            matches = [ { app-id = "firefox"; } ];
            open-on-workspace = "default";
          }
          {
            matches = [ { app-id = "thunderbird"; } ];
            open-on-workspace = "mail";
            block-out-from = "screen-capture";
          }
          {
            matches = [ { app-id = "steam"; } ];
            open-on-workspace = "games";
          }
          {
            matches = [ { app-id = "signal"; } ];
            open-on-workspace = "comms";
            block-out-from = "screencast";
          }
          {
            matches = [ { app-id = "discord"; } ];
            open-on-workspace = "comms";
            block-out-from = "screencast";
          }
          {
            matches = [ { app-id = "affine"; } ];
            open-on-workspace = "notes";
            block-out-from = "screencast";
          }
        ];

        layout = {
          gaps = 1;
          center-focused-column = "never";
          empty-workspace-above-first = true;

          preset-column-widths = [
            { proportion = 0.33333; }
            { proportion = 0.5; }
            { proportion = 0.66667; }
          ];

          default-column-width = {
            proportion = 0.5;
          };

          preset-window-heights = [
            { proportion = 0.33333; }
            { proportion = 0.5; }
            { proportion = 0.66667; }
          ];

          focus-ring = {
            enable = true;
            width = 2;
            active.color = "#7fc8ff";
            inactive.color = "#505050";
          };

          border = {
            enable = false;
            width = 2;
            active.color = "#ffc87f";
            inactive.color = "#505050";
          };

          shadow = {
            # on
            softness = 30;
            spread = 5;
            offset = {
              x = 0;
              y = 5;
            };
            draw-behind-window = true;
            color = "#00000070";
            # inactive-color "#00000054"
          };

          tab-indicator = {
            # off
            hide-when-single-tab = true;
            place-within-column = true;
            gap = 5;
            width = 4;
            length = {
              total-proportion = 1.0;
            };
            position = "right";
            gaps-between-tabs = 2;
            corner-radius = 8;
            active.color = "red";
            inactive.color = "gray";
          };

          insert-hint = {
            # off
            display.color = "#ffc87f80";
          };
        };
      }

      (mkIf (nixosConfig.node.name == "kroma") {
        outputs = {
          "DP-2" = {
            mode = {
              width = 3840;
              height = 2160;
              refresh = 120.0;
            };
            position = {
              x = 0;
              y = 0;
            };
            variable-refresh-rate = "on-demand";
          };
          "DP-3" = {
            position = {
              x = -3840;
              y = 0;
            };
            variable-refresh-rate = "on-demand";
          };
          "Unknown-1" = {
            enable = false;
          };
        };

        workspaces = {
          "1browser" = {
            name = "browser";
            open-on-output = "DP-2";
          };
          "2default" = {
            name = "default";
            open-on-output = "DP-2";
          };
          "3term" = {
            name = "term";
            open-on-output = "DP-2";
          };
          "5games" = {
            name = "games";
            open-on-output = "DP-2";
          };

          "7browser" = {
            name = "browser2";
            open-on-output = "DP-3";
          };
          "8comms" = {
            name = "comms";
            open-on-output = "DP-3";
          };
          "9notes" = {
            name = "notes";
            open-on-output = "DP-3";
          };
        };
      })
    ];
  };
}
