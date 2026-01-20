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
    pkgs.wl-clipboard-rs
  ];

  services.gnome-keyring.enable = true;
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config.niri = {
      default = [
        "gtk"
        "gnome"
      ];
      "org.freedesktop.impl.portal.Access" = [ "gtk" ];
      "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "xdg-desktop-portal-gnome" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "xdg-desktop-portal-gnome" ];
    };
    extraPortals = [
      pkgs.gnome-keyring
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
  };

  # Autostart niri if on tty1 (once, don't restart after logout)
  programs.zsh.initContent = lib.mkOrder 9999 ''
    if [[ -t 0 && "$(tty || true)" == /dev/tty1 && -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
      echo "Login shell detected. Starting wayland..."
      niri-session
    fi
  '';

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
            accel-speed = -0.5;
            accel-profile = "flat";
          };

          power-key-handling.enable = false;
          workspace-auto-back-and-forth = false;
        };

        gestures.hot-corners.enable = false;

        binds = with config.lib.niri.actions; {
          "Mod+t".action = spawn "kitty";
          "Mod+c".action = spawn (getExe pkgs.scripts.clone-term);
          "Mod+b".action = spawn "firefox";
          "Menu".action = spawn "fuzzel";
          "Mod+asciicircum".action = spawn "fuzzel";
          "Mod+Alt+l".action = spawn "systemctl suspend";

          "Mod+q".action = close-window;
          "Mod+f".action = toggle-window-floating;
          "Mod+Ctrl+f".action = switch-focus-between-floating-and-tiling;
          "Mod+Return".action = maximize-column;
          "Mod+Ctrl+Return".action = expand-column-to-available-width;
          "Mod+Space".action = fullscreen-window;

          "Mod+Left".action = focus-column-left;
          "Mod+Right".action = focus-column-right;
          "Mod+Up".action = focus-window-or-workspace-up;
          "Mod+Down".action = focus-window-or-workspace-down;

          "Mod+Shift+Left".action = move-column-left;
          "Mod+Shift+Right".action = move-column-right;
          "Mod+Shift+Up".action = move-window-up;
          "Mod+Shift+Down".action = move-window-down;

          "Mod+Ctrl+Left".action = focus-monitor-left;
          "Mod+Ctrl+Right".action = focus-monitor-right;
          "Mod+Ctrl+Up".action = focus-monitor-up;
          "Mod+Ctrl+Down".action = focus-monitor-down;

          "Mod+Shift+Ctrl+Left".action = move-column-to-monitor-left;
          "Mod+Shift+Ctrl+Right".action = move-column-to-monitor-right;
          "Mod+Shift+Ctrl+Up".action = move-column-to-monitor-up;
          "Mod+Shift+Ctrl+Down".action = move-column-to-monitor-down;

          "Mod+Home".action = focus-column-first;
          "Mod+End".action = focus-column-last;
          "Mod+Alt+Left".action = consume-or-expel-window-left;
          "Mod+Alt+Right".action = consume-or-expel-window-right;
          "Mod+y".action = toggle-column-tabbed-display;

          "Mod+Shift+s".action.screenshot = [ ]; # XXX : https://github.com/sodiboo/niri-flake/issues/1380

          "Mod+Escape" = {
            action = toggle-keyboard-shortcuts-inhibit;
            allow-inhibiting = false;
          };

          # The quit action will show a confirmation dialog to avoid accidental exits.
          "Mod+Ctrl+Shift+q".action = quit;
          # Powers off the monitors. To turn them back on, do any input like
          # moving the mouse or pressing any other key.
          "Mod+Shift+p".action = power-off-monitors;

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
          "Mod+MouseForward" = {
            action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle";
            allow-when-locked = true;
          };
        };

        window-rules = [
          {
            matches = [ { app-id = "firefox"; } ];
            open-on-workspace = "browser";
            open-maximized = true;
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
          "DP-3" = {
            mode = {
              width = 3840;
              height = 2160;
              refresh = 240.000;
            };
            scale = 1.5;
            position = {
              x = 0;
              y = 0;
            };
            variable-refresh-rate = "on-demand";
          };
          "DP-2" = {
            mode = {
              width = 3840;
              height = 2160;
              refresh = 143.999;
            };
            scale = 1.5;
            position = {
              x = -2560; # -3840 / 1.5
              y = 0;
            };
            variable-refresh-rate = "on-demand";
          };
        };

        workspaces =
          let
            ws = open-on-output: name: { inherit name open-on-output; };
          in
          {
            "1browser" = ws "DP-3" "browser";
            "2default" = ws "DP-3" "default";
            "3term" = ws "DP-3" "term";
            "4term2" = ws "DP-3" "term2";
            "5games" = ws "DP-3" "games";
            "6misc" = ws "DP-3" "misc";

            "7comms" = ws "DP-2" "comms";
            "8browser2" = ws "DP-2" "browser2";
            "9notes" = ws "DP-2" "notes";
          };

        binds =
          let
            mappings = {
              "browser" = "1";
              "default" = "2";
              "term" = "3";
              "term2" = "4";
              "games" = "5";
              "misc" = "6";
              "comms" = "7";
              "browser2" = "8";
              "notes" = "9";
            };
          in
          lib.mergeAttrsList (
            lib.mapAttrsToList (
              workspace: key: with config.lib.niri.actions; {
                "Mod+${key}".action = focus-workspace workspace;
                "Mod+Shift+${key}".action.move-window-to-workspace = [
                  { focus = false; }
                  workspace
                ];
              }
            ) mappings
          );
      })

      (mkIf (nixosConfig.node.name == "nom") {
        workspaces = {
          "1browser".name = "browser";
          "2default".name = "default";
          "3term".name = "term";
          "4term2".name = "term2";
          "5games".name = "games";
          "6misc".name = "misc";

          "7comms".name = "comms";
          "8browser2".name = "browser2";
          "9notes".name = "notes";
        };

        binds =
          let
            mappings = {
              "browser" = "1";
              "default" = "2";
              "term" = "3";
              "term2" = "4";
              "games" = "5";
              "misc" = "6";
              "comms" = "7";
              "browser2" = "8";
              "notes" = "9";
            };
          in
          lib.mergeAttrsList (
            lib.mapAttrsToList (
              workspace: key: with config.lib.niri.actions; {
                "Mod+${key}".action = focus-workspace workspace;
                "Mod+Shift+${key}".action.move-window-to-workspace = [
                  { focus = false; }
                  workspace
                ];
              }
            ) mappings
          );
      })
    ];
  };
}
