{
  lib,
  nixosConfig,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    wl-clipboard
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      env =
        lib.optionals (lib.elem "nvidia" nixosConfig.services.xserver.videoDrivers) [
          # See https://wiki.hyprland.org/Nvidia/
          "LIBVA_DRIVER_NAME,nvidia"
          "XDG_SESSION_TYPE,wayland"
          "GBM_BACKEND,nvidia-drm"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        ]
        ++ [
          "NIXOS_OZONE_WL,1"
          "MOZ_ENABLE_WAYLAND,1"
          "MOZ_WEBRENDER,1"
          "_JAVA_AWT_WM_NONREPARENTING,1"
          "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
          "QT_QPA_PLATFORM,wayland"
          "SDL_VIDEODRIVER,wayland"
          "GDK_BACKEND,wayland"
        ];

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

      # FIXME: TODO refactor and use mkmerge, this is ugly
      monitor =
        {
          kroma = [
            "DP-2, preferred, 0x0, 1"
            "DP-3, preferred, -3840x0, 1"
            "Unknown-1, disable"
          ];
          nom = [
          ];
        }
        .${nixosConfig.node.name}
        or [];

      workspace =
        {
          kroma = [
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
          nom = [
          ];
        }
        .${nixosConfig.node.name}
        or [];

      cursor.no_warps = true;

      input = {
        kb_layout = "de";
        follow_mouse = 2;
        numlock_by_default = true;
        repeat_rate = 60;
        repeat_delay = 235;
        # Only change focus on mouse click
        float_switch_override_focus = 0;
        accel_profile = "flat";

        touchpad = {
          natural_scroll = "no";
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

      debug.disable_logs = false;

      misc = {
        vfr = 1;
        vrr = 1;
        disable_hyprland_logo = true;
        mouse_move_focuses_monitor = false;
      };
    };
    extraConfig =
      # TODO: env = WLR_DRM_NO_ATOMIC,1
      ''
        windowrulev2 = immediate, class:^(cs2)$

        binds {
          focus_preferred_method = 1
        }

        # keybinds
        bind=SUPER,q,killactive,
        bind=SUPER,return,fullscreen,
        bind=SUPER,f,togglefloating
        bind=SUPER,tab,cyclenext,
        bind=ALT,tab,cyclenext,
        bind=,Menu,exec,rofi -show drun

        bind=SUPER,left,movefocus,l
        bind=SUPER,right,movefocus,r
        bind=SUPER,up,movefocus,u
        bind=SUPER,down,movefocus,d

        bind=SUPER + SHIFT,left,movewindow,l
        bind=SUPER + SHIFT,right,movewindow,r
        bind=SUPER + SHIFT,up,movewindow,u
        bind=SUPER + SHIFT,down,movewindow,d

        bindm=SUPER,mouse:272,movewindow

        bind=SUPER,comma,workspace,-1
        bind=SUPER,period,workspace,+1

        bind=SUPER,b,exec,firefox
        bind=SUPER,t,exec,kitty
        bind=SUPER + CTRL + SHIFT,q,exit
      ''
      + builtins.concatStringsSep "\n" (
        map (
          x: ''
            bind=SUPER,${x},workspace,${x}
            bind=SUPER + SHIFT,${x},movetoworkspacesilent,${x}
          ''
        )
        (map toString (lib.lists.range 1 9))
      );
  };
}
