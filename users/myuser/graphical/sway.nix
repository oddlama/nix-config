# - hyprland ctl dispatch rewrite
# - software rendering used
# - no wlr render env ok?

# TODO: screencast button with notification
# TODO: better qr script: click button, freeze screen, highlight qrs, overlay preview detected text, click to copy.
# TODO ai speech indicator / toggle
{
  lib,
  config,
  nixosConfig,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe
    mapAttrs'
    nameValuePair
    ;

  cfg = config.wayland.windowManager.sway.config;
  bindWithModifier = mapAttrs' (k: nameValuePair (cfg.modifier + "+" + k));
in
{
  wayland.windowManager.sway = {
    enable = true;
    systemd.enable = false; # Handeled by uwsm
    extraOptions = [
      "-Dlegacy-wl-drm" # Otherwise no app will run on the nvidia card for some reason and fall back to mesa libGL
      "--unsupported-gpu"
    ];

    config =
      {
        modifier = "Mod4";
        terminal = "kitty";
        menu = "fuzzel";

        # Excuse me, le füque
        focus.followMouse = false;
        focus.mouseWarping = false;

        keybindings =
          {
            "XF86AudioRaiseVolume" =
              "exec --no-startup-id ${getExe pkgs.scripts.volume} set-volume @DEFAULT_AUDIO_SINK@ 5%+";
            "XF86AudioLowerVolume" =
              "exec --no-startup-id ${getExe pkgs.scripts.volume} set-volume @DEFAULT_AUDIO_SINK@ 5%-";
            "XF86AudioMute" =
              "exec --no-startup-id ${getExe pkgs.scripts.volume} set-mute @DEFAULT_AUDIO_SINK@ toggle";
            "XF86AudioMicMute" =
              "exec --no-startup-id ${getExe pkgs.scripts.volume} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            "XF86AudioPlay" = "exec --no-startup-id ${getExe pkgs.playerctl} play-pause";
            "XF86AudioNext" = "exec --no-startup-id ${getExe pkgs.playerctl} next";
            "XF86AudioPrev" = "exec --no-startup-id ${getExe pkgs.playerctl} previous";
            "XF86MonBrightnessUp" = "exec --no-startup-id ${getExe pkgs.scripts.brightness} set +5%";
            "XF86MonBrightnessDown" = "exec --no-startup-id ${getExe pkgs.scripts.brightness} set 5%-";
          }
          // {
            "Menu" = "exec ${cfg.menu}";
          }
          # General mappings that start with $modifier+...
          // bindWithModifier {
            "t" = "exec ${cfg.terminal}";
            "asciicircum" = "exec ${cfg.menu}";
            # TODO only open if not already open
            # TODO shortcut to open these from eww bar with 1 click
            "b" = "exec uwsm app firefox";
            "Shift+s" = "exec --no-startup-id ${getExe pkgs.scripts.screenshot-area}";
            "F11" = "exec --no-startup-id ${getExe pkgs.scripts.screenshot-area-scan-qr}";
            # Exlicitly without --no-startup-id to show the spinner
            "F12" = "exec ${getExe pkgs.scripts.screenshot-screen}";
            "Print" =
              "exec --no-startup-id env QT_AUTO_SCREEN_SCALE_FACTOR=0 QT_SCREEN_SCALE_FACTORS='' ${getExe pkgs.flameshot} gui";

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

            "space" = "layout toggle tabbed splitv splith";
            "s" = "splith";
            "v" = "splitv";
            "f" = "floating toggle";
            "Return" = "fullscreen toggle";
            "a" = "focus parent";

            "Shift+Ctrl+q" = "exec uwsm stop";
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

        floating.criteria = [
          { class = "^Pavucontrol$"; }
          #{class = "^awakened-poe-trade$";}
        ];

        assigns = {
          "1" = [
            { class = "^firefox$"; }
          ];
          "5" = [
            { class = "^bottles$"; }
            { class = "^steam$"; }
            { class = "^prismlauncher$"; }
          ];
          "7" = [
            { class = "^discord$"; }
            { class = "^WebCord$"; }
            { class = "^obsidian$"; }
            { class = "^signal$"; }
            { class = "^TelegramDesktop$"; }
          ];
        };

        bars = [ ];

        startup = [
          { command = "uwsm finalize"; }
        ];
      }
      # Extra configuration based on which system we are on. It's not ideal to
      # distinguish by node name here, but at least this way it can stay in the
      # sway related config file.
      // {
        kroma =
          let
            monitorMain = "LG Electronics 27GN950 111NTGYLB719";
            monitorLeft = "LG Electronics LG Ultra HD 0x00077939";
          in
          {
            output = {
              # TODO "*" = { background = background; };
              ${monitorLeft} = {
                mode = "3840x2160@60Hz";
                pos = "0 0";
                adaptive_sync = "enable";
                subpixel = "rgb";
                allow_tearing = "yes";
              };
              ${monitorMain} = {
                mode = "3840x2160@144Hz";
                pos = "3840 0";
                adaptive_sync = "enable";
                subpixel = "rgb";
                render_bit_depth = "10";
                allow_tearing = "yes";
              };
            };

            workspaceOutputAssign = [
              {
                workspace = "1";
                output = monitorMain;
              }
              {
                workspace = "2";
                output = monitorMain;
              }
              {
                workspace = "3";
                output = monitorMain;
              }
              {
                workspace = "4";
                output = monitorMain;
              }
              {
                workspace = "5";
                output = monitorMain;
              }
              {
                workspace = "6";
                output = monitorMain;
              }
              {
                workspace = "7";
                output = monitorLeft;
              }
              {
                workspace = "8";
                output = monitorLeft;
              }
              {
                workspace = "9";
                output = monitorLeft;
              }
            ];
          };
      }
      .${nixosConfig.node.name} or { };

    extraConfig = ''
      for_window [app_id="kitty"] allow_tearing yes
      for_window [class="^cs2$"] allow_tearing yes
    '';
  };

  home.file.".config/uwsm/env-sway".text = ''
    # Let nixos electron wrappers enable wayland
    export NIXOS_OZONE_WL=1
  '';

  home.packages = with pkgs; [
    wdisplays
    wl-clipboard
  ];
}
