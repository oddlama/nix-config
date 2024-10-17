# TODO: screencast button with notification
# TODO: better qr script: click button, freeze screen, highlight qrs, overlay preview detected text, click to copy.
# TODO ai speech indicator / toggle
{
  config,
  lib,
  nixosConfig,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatMap
    elem
    flip
    getExe
    mkIf
    mkMerge
    optionals
    ;

  rofi-drun = "rofi -show drun -theme ~/.config/rofi/launchers/type-1/style-10.rasi";
in {
  home.packages = with pkgs; [
    wl-clipboard
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    settings = mkMerge [
      {
        env =
          optionals (elem "nvidia" nixosConfig.services.xserver.videoDrivers) [
            # See https://wiki.hyprland.org/Nvidia/
            "LIBVA_DRIVER_NAME,nvidia"
            "GBM_BACKEND,nvidia-drm"
            # "__GLX_VENDOR_LIBRARY_NAME,nvidia" breaks orcaslicer and doesn't seem like a good idea in general
          ]
          ++ [
            "XDG_SESSION_TYPE,wayland"
            "NIXOS_OZONE_WL,1"
            "MOZ_ENABLE_WAYLAND,1"
            "_JAVA_AWT_WM_NONREPARENTING,1"
            "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
            "QT_QPA_PLATFORM,wayland"
            # "SDL_VIDEODRIVER,wayland"
            "GDK_BACKEND,wayland"
          ];

        bind =
          [
            "SUPER + CTRL + SHIFT,q,exit"

            # Applications
            "SUPER,code:49,exec,${rofi-drun}" # SUPER+^
            ",Menu,exec,${rofi-drun}"
            "SUPER,t,exec,kitty"
            "SUPER,b,exec,firefox"
            "SUPER,c,exec,${getExe pkgs.scripts.clone-term}"

            # Shortcuts & Actions
            "SUPER + SHIFT,s,exec,${getExe pkgs.scripts.screenshot-area}"
            "SUPER,F11,exec,${getExe pkgs.scripts.screenshot-area-scan-qr}"
            "SUPER,F12,exec,${getExe pkgs.scripts.screenshot-screen}"

            "SUPER,End,exec,${getExe config.lib.gpu-screen-recorder.save-replay}"
            "SUPER,Prior,exec,systemctl --user restart gpu-screen-recorder.service"
            "SUPER,Next,exec,systemctl --user stop gpu-screen-recorder.service"

            # Per-window actions
            "SUPER,q,killactive,"
            "SUPER,return,fullscreen,"
            "SUPER + SHIFT,return,fullscreenstate,0 2"
            "SUPER,f,togglefloating"

            "SUPER,tab,cyclenext,"
            "ALT,tab,cyclenext,"
            "SUPER + SHIFT,tab,cyclenext,prev"
            "ALT + SHIFT,tab,cyclenext,prev"
            "SUPER,r,submap,resize"

            "SUPER,left,movefocus,l"
            "SUPER,right,movefocus,r"
            "SUPER,up,movefocus,u"
            "SUPER,down,movefocus,d"

            "SUPER + SHIFT,left,movewindow,l"
            "SUPER + SHIFT,right,movewindow,r"
            "SUPER + SHIFT,up,movewindow,u"
            "SUPER + SHIFT,down,movewindow,d"

            "SUPER,comma,workspace,-1"
            "SUPER,period,workspace,+1"
            "SUPER + SHIFT,comma,movetoworkspacesilent,-1"
            "SUPER + SHIFT,period,movetoworkspacesilent,+1"
          ]
          ++ flip concatMap (map toString (lib.lists.range 1 9)) (
            x: [
              "SUPER,${x},workspace,${x}"
              "SUPER + SHIFT,${x},movetoworkspacesilent,${x}"
            ]
          );

        bindm = [
          # mouse movements
          "SUPER, mouse:272, movewindow"
          "SUPER, mouse:273, resizewindow"
          "SUPER ALT, mouse:272, resizewindow"
        ];

        animations = {
          enabled = true;
          animation = [
            "windows, 1, 4, default, slide"
            "windowsOut, 1, 4, default, slide"
            "windowsMove, 1, 4, default"
            "border, 1, 2, default"
            "fade, 1, 4, default"
            "fadeDim, 1, 4, default"
            "workspaces, 1, 4, default"
          ];
        };

        decoration.rounding = 4;
        exec-once = [
          "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "systemctl --user restart xdg-desktop-portal.service"
          "${pkgs.waybar}/bin/waybar"
          "${pkgs.swaynotificationcenter}/bin/swaync"
          "${lib.getExe pkgs.whisper-overlay}"
        ];

        input = {
          kb_layout = "de";
          kb_variant = "nodeadkeys";
          follow_mouse = 2;
          numlock_by_default = true;
          repeat_rate = 60;
          repeat_delay = 235;
          # Only change focus on mouse click
          float_switch_override_focus = 0;
          accel_profile = "flat";

          touchpad = {
            natural_scroll = false;
            disable_while_typing = true;
            clickfinger_behavior = true;
            scroll_factor = 0.7;
          };
        };

        general = {
          gaps_in = 1;
          gaps_out = 0;
          allow_tearing = true;
        };

        cursor.no_warps = true;
        cursor.no_hardware_cursors = true;
        debug.disable_logs = false;

        misc = {
          vrr = 1; # 1 = always on
          disable_hyprland_logo = true;
          mouse_move_focuses_monitor = false;
        };
      }
      (mkIf (nixosConfig.node.name == "kroma") {
        monitor = [
          "DP-2, preferred, 0x0, 1"
          "DP-3, preferred, -3840x0, 1"
          # Thank you NVIDIA for this generous, free-of-charge, extra monitor that
          # doesn't exist and crashes yoru session sometimes when moving a window to it.
          "Unknown-1, disable"
        ];

        windowrulev2 = [
          "workspace 1,class:^(firefox)$"
          "workspace 5,class:^(bottles)$"
          "workspace 5,class:^(steam)$"
          "float, class:^(SDL Application)$, title:^(Friends List)$"
          "workspace 5,class:^(SDL Application)$, title:^(Steam)$"
          "workspace 5,class:^(prismlauncher)$"
          "workspace 7,class:^(discord)$"
          "workspace 7,class:^(WebCord)$"
          "workspace 7,class:^(obsidian)$"
          "workspace 7,class:^(signal)$"
          "workspace 7,class:^(TelegramDesktop)$"
        ];

        workspace = [
          "1, monitor:DP-2, default:true"
          "2, monitor:DP-2"
          "3, monitor:DP-2"
          "4, monitor:DP-2"
          "5, monitor:DP-2"
          "6, monitor:DP-2"
          "7, monitor:DP-3, default: true"
          "8, monitor:DP-3"
          "9, monitor:DP-3"
        ];
      })
      (mkIf (nixosConfig.node.name == "nom") {
        monitor = [
        ];
        workspace = [
        ];
      })
    ];

    extraConfig = ''
      submap=resize
      binde=,right,resizeactive,80 0
      binde=,left,resizeactive,-80 0
      binde=,up,resizeactive,0 -80
      binde=,down,resizeactive,0 80
      binde=SHIFT,right,resizeactive,10 0
      binde=SHIFT,left,resizeactive,-10 0
      binde=SHIFT,up,resizeactive,0 -10
      binde=SHIFT,down,resizeactive,0 10
      bind=,return,submap,reset
      bind=,escape,submap,reset
      submap=reset

      env=WLR_DRM_NO_ATOMIC,1
      windowrulev2 = immediate, class:^(cs2)$

      windowrulev2 = tag +apt, title:(Awakened PoE Trade)
      windowrulev2 = float, tag:apt
      windowrulev2 = noblur, tag:apt
      windowrulev2 = nofocus, tag:apt # Disable auto-focus
      windowrulev2 = noshadow, tag:apt
      windowrulev2 = noborder, tag:apt
      windowrulev2 = size 100% 100%, tag:apt
      windowrulev2 = center, tag:apt

      binds {
        focus_preferred_method = 1
      }
    '';
  };
}
