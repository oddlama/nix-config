{
  lib,
  config,
  nixosConfig,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mapAttrs'
    nameValuePair
    ;

  bindWithModifier = mapAttrs' (k: nameValuePair (cfg.modifier + "+" + k));
  cfg = config.wayland.windowManager.sway.config;
in {
  wayland.windowManager.sway = {
    enable = true;
    config =
      {
        modifier = "Mod4";
        terminal = "kitty";

        # Excuse me, le füque
        focus.followMouse = false;
        focus.mouseWarping = false;

        # TODO menu = "rofi -show run";

        keybindings =
          {
            "XF86AudioRaiseVolume" = "exec --no-startup-id wpctl set-sink-volume @DEFAULT_SINK@ +5%";
            "XF86AudioLowerVolume" = "exec --no-startup-id wpctl set-sink-volume @DEFAULT_SINK@ -5%";
            "XF86AudioMute" = "exec --no-startup-id wpctl set-sink-mute @DEFAULT_SINK@ toggle";
            "XF86AudioMicMute" = "exec --no-startup-id wpctl set-source-mute @DEFAULT_SOURCE@ toggle";

            #"Print" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot copy area";
            #"${mod}+Print" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save area";
          }
          # // optionalAttrs useBacklight {
          #   "XF86MonBrightnessUp" = "exec ${pkgs.light}/bin/light -A 5";
          #   "XF86MonBrightnessDown" = "exec ${pkgs.light}/bin/light -U 5";
          # }
          // {
            "Menu" = "exec ${cfg.menu}";
          }
          # General mappings that start with $modifier+...
          // bindWithModifier {
            "t" = "exec ${cfg.terminal}";
            "asciicircum" = "exec ${cfg.menu}";
            "b" = "exec firefox";

            "Shift+r" = "reload";
            "q" = "kill";

            "Left" = "focus left";
            "Right" = "focus right";
            "Up" = "focus up";
            "Down" = "focus down";

            "Shift+Left" = "move left";
            "Shift+Right" = "move right";
            "Shift+Up" = "move up";
            "Shift+Down" = "move down";

            "s" = "splith";
            "v" = "splitv";
            "f" = "floating toggle";
            "Return" = "fullscreen toggle";
            "Space" = "focus mode_toggle";
            # "a" = "focus parent";
            # "s" = "layout stacking";
            # "w" = "layout tabbed";
            # "e" = "layout toggle split";

            "Shift+Ctrl+q" = "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -b 'Yes, exit sway' 'swaymsg exit'";
            "r" = "mode resize";

            "1" = "workspace number 1";
            "2" = "workspace number 2";
            "3" = "workspace number 3";
            "4" = "workspace number 4";
            "5" = "workspace number 5";
            "6" = "workspace number 6";
            "7" = "workspace number 7";
            "8" = "workspace number 8";
            "9" = "workspace number 9";
            "Comma" = "workspace prev";
            "Period" = "workspace next";

            "Shift+1" = "move container to workspace number 1";
            "Shift+2" = "move container to workspace number 2";
            "Shift+3" = "move container to workspace number 3";
            "Shift+4" = "move container to workspace number 4";
            "Shift+5" = "move container to workspace number 5";
            "Shift+6" = "move container to workspace number 6";
            "Shift+7" = "move container to workspace number 7";
            "Shift+8" = "move container to workspace number 8";
            "Shift+9" = "move container to workspace number 9";
            "Shift+Comma" = "move container to workspace prev";
            "Shift+Period" = "move container to workspace next";
          };

        window.titlebar = false;

        input = {
          "type:keyboard" = {
            repeat_delay = "235";
            repeat_rate = "60";
            xkb_layout = "de";
            xkb_variant = "nodeadkeys";
            xkb_numlock = "enabled";
          };
          "type:pointer" = {
            accel_profile = "flat";
            pointer_accel = "0";
          };
        };

        assigns = {
          "9" = [
            {class = "^steam_app_";}
            {app_id = "^Steam$";}
            {class = "^steam$";}
          ];
        };
        # TODO eww -> bars = [ ];
      }
      # Extra configuration based on which system we are on. It's not ideal to
      # distinguish by node name here, but at least this way it can stay in the
      # sway related config file.
      // {
        kroma = let
          monitorMain = "LG Electronics 27GN950 111NTGYLB719";
          monitorLeft = "LG Electronics LG Ultra HD 0x00077939";
        in {
          output = {
            # TODO "*" = { background = background; };
            ${monitorLeft} = {
              mode = "3840x2160@60Hz";
              pos = "0 0";
              adaptive_sync = "enable";
              subpixel = "rgb";
            };
            ${monitorMain} = {
              mode = "3840x2160@144Hz";
              pos = "3840 0";
              adaptive_sync = "enable";
              subpixel = "rgb";
              render_bit_depth = "10";
            };
          };
          workspaceOutputAssign = [
            {
              workspace = "1";
              output = monitorMain;
            }
            {
              workspace = "7";
              output = monitorLeft;
            }
          ];
        };
      }
      .${nixosConfig.node.name}
      or {};
  };

  home.sessionVariables = {
    # Let nixos electron wrappers enable wayland
    NIXOS_OZONE_WL = 1;
    # Cursor is invisible otherwise
    # XXX: retest in 2024
    WLR_NO_HARDWARE_CURSORS = 1;
    # opengl backend flickers, also vulkan is love.
    WLR_RENDERER = "vulkan";
  };

  home.packages = with pkgs; [
    wdisplays
    wl-clipboard
  ];
}
