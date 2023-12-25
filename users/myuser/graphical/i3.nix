{
  lib,
  config,
  nixosConfig,
  pkgs,
  ...
}: let
  inherit
    (lib)
    escapeShellArg
    getExe
    mapAttrs'
    nameValuePair
    ;

  bindWithModifier = mapAttrs' (k: nameValuePair (cfg.modifier + "+" + k));
  cfg = config.xsession.windowManager.i3.config;

  i3-per-workspace-layout = pkgs.rustPlatform.buildRustPackage {
    pname = "i3-per-workspace-layout";
    version = "1.0.0";

    src = ./i3-per-workspace-layout;
    cargoHash = "sha256-SThuQB1O3RSBIfY3W8By9mL5tZ4aY4XSSgNXlG7TWDQ=";

    meta = with lib; {
      description = "A helper utility to allow assigning a layout to each workspace in i3";
      license = licenses.mit;
      maintainers = with maintainers; [oddlama];
      mainProgram = "i3-per-workspace-layout";
    };
  };

  sway-overfocus = pkgs.rustPlatform.buildRustPackage {
    pname = "sway-overfocus";
    version = "1.0.0";

    src = pkgs.fetchFromGitHub {
      owner = "korreman";
      repo = "sway-overfocus";
      rev = "8c2a80fd111dcb9ce7e956b867c0d0180b13b649";
      hash = "sha256-Rv4dTycB19c2JyQ0y5WpDpX15D2RhjKq2lPOyuK2Ki8=";
    };
    cargoHash = "sha256-mwPLroz7oE7NNdc/H/sH9mnXj3KyT75U55UE7tMyZMw=";

    meta = with lib; {
      description = "Better focus navigation for sway and i3";
      license = licenses.mit;
      maintainers = with maintainers; [oddlama];
      mainProgram = "sway-overfocus";
    };
  };
in {
  xsession.numlock.enable = true;
  xsession.windowManager.i3 = {
    enable = true;
    enableSystemdTarget = true;
    config = {
      modifier = "Mod4";
      terminal = "kitty";

      # Excuse me, le füque
      focus.followMouse = false;
      focus.mouseWarping = false;

      # TODO menu = "rofi -show run";

      keybindings =
        {
          "XF86AudioRaiseVolume" = "exec --no-startup-id ${getExe pkgs.scripts.volume} set-volume @DEFAULT_AUDIO_SINK@ 5%+";
          "XF86AudioLowerVolume" = "exec --no-startup-id ${getExe pkgs.scripts.volume} set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          "XF86AudioMute" = "exec --no-startup-id ${getExe pkgs.scripts.volume} set-mute @DEFAULT_AUDIO_SINK@ toggle";
          "XF86AudioMicMute" = "exec --no-startup-id ${getExe pkgs.scripts.volume} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
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
          "b" = "exec firefox"; # TODO ; exec signal-desktop; exec discord
          "Shift+s" = "exec --no-startup-id ${getExe pkgs.scripts.screenshot-area}";
          "F11" = "exec --no-startup-id ${getExe pkgs.scripts.screenshot-area-scan-qr}";
          # Exlicitly without --no-startup-id to show the spinner
          "F12" = "exec ${getExe pkgs.scripts.screenshot-screen}";
          "Print" = "exec --no-startup-id env QT_AUTO_SCREEN_SCALE_FACTOR=0 QT_SCREEN_SCALE_FACTORS='' ${getExe pkgs.flameshot} gui";

          "Shift+r" = "reload";
          "q" = "kill";

          # Don't focus tabs
          "Left" = "exec --no-startup-id ${getExe sway-overfocus} split-lt float-lt output-ls";
          "Right" = "exec --no-startup-id ${getExe sway-overfocus} split-rt float-rt output-rs";
          "Up" = "exec --no-startup-id ${getExe sway-overfocus} split-ut float-ut output-us";
          "Down" = "exec --no-startup-id ${getExe sway-overfocus} split-dt float-dt output-ds";
          "Tab" = "exec --no-startup-id ${getExe sway-overfocus} group-rw group-dw";
          "Shift+Tab" = "exec --no-startup-id ${getExe sway-overfocus} group-lw group-uw";

          "Shift+Left" = "move left";
          "Shift+Right" = "move right";
          "Shift+Up" = "move up";
          "Shift+Down" = "move down";

          "space" = "layout toggle tabbed splitv splith";
          "s" = "splitv";
          "v" = "splith";
          "f" = "floating toggle";
          "Shift+f" = "focus mode_toggle";
          "Return" = "fullscreen toggle";
          "a" = "focus parent";

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

      floating.criteria = [
        {class = "^Pavucontrol$";}
      ];

      assigns = {
        "1" = [
          {class = "^firefox$";}
        ];
        "5" = [
          {class = "^bottles$";}
          {class = "^steam$";}
          {class = "^prismlauncher$";}
        ];
        "7" = [
          {class = "^obsidian$";}
          {class = "^discord$";}
          {class = "^Signal$";}
          {class = "^TelegramDesktop$";}
        ];
        "8" = [
          {class = "^Spotify$";}
        ];
      };
      # TODO eww -> bars = [ ];

      workspaceOutputAssign =
        {
          kroma = let
            monitorMain = "DP-2";
            monitorLeft = "DP-4";
          in
            map (x: {
              workspace = x;
              output = monitorMain;
            }) ["1" "2" "3" "4" "5" "6"]
            ++ map (x: {
              workspace = x;
              output = monitorLeft;
            }) ["7" "8" "9"];
        }
        .${nixosConfig.node.name}
        or [];

      startup = let
        configLayouts = (pkgs.formats.toml {}).generate "per-workspace-layouts.toml" {
          force = true;
          layouts = {
            "1" = "tabbed";
            "5" = "tabbed";
            "7" = "tabbed";
            "8" = "tabbed";
            "9" = "tabbed";
          };
        };
      in [
        {
          command = "${getExe i3-per-workspace-layout} --config ${configLayouts}";
          always = false;
          notification = false;
        }
      ];
    };
  };

  systemd.user.services = {
    wired.Install.WantedBy = lib.mkForce ["i3-session.target"];
    flameshot.Install.WantedBy = lib.mkForce ["i3-session.target"];
  };

  programs.autorandr.enable = true;
  programs.autorandr.profiles =
    {
      kroma = let
        monitorMain = "DP-2";
        monitorLeft = "DP-4";
      in {
        main = {
          config = {
            ${monitorLeft} = {
              enable = true;
              mode = "3840x2160";
              rate = "60.00";
              position = "0x0";
            };
            ${monitorMain} = {
              enable = true;
              primary = true;
              mode = "3840x2160";
              rate = "144.00";
              position = "3840x0";
            };
          };
          fingerprint = {
            ${monitorMain} = "00ffffffffffff001e6d9a5b078e0a000b1f0104b53c2278f919c1ae5044af260e5054210800d1c061404540314001010101010101014dd000a0f0703e803020350058542100001a000000fd0c3090505086010a202020202020000000fc003237474e3935300a2020202020000000ff003131314e5447594c423731390a02e602032d7123090707830100004410040301e2006ae305c000e60605017360216d1a0000020b309000047321602900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f47012790300030128d8060284ff0e9f002f801f006f08910002000400404f0104ff0e9f002f801f006f086200020004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006d90";
            ${monitorLeft} = "00ffffffffffff001e6d095b39790700081a0104b53c22789f3035a7554ea3260f50542108007140818081c0a9c0d1c08100010101014dd000a0f0703e803020650c58542100001a286800a0f0703e800890650c58542100001a000000fd00283d878738010a202020202020000000fc004c4720556c7472612048440a2001850203117144900403012309070783010000023a801871382d40582c450058542100001e565e00a0a0a029503020350058542100001a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c8";
          };
        };
      };
    }
    .${nixosConfig.node.name}
    or {};

  home.sessionVariables = {
    # Make gtk apps bigger
    GDK_SCALE = 2;
    # Make QT apps bigger
    QT_SCREEN_SCALE_FACTORS = 2;
  };

  xsession.wallpapers.enable = true;

  home.file.".xinitrc".text = ''
    if test -z "$DBUS_SESSION_BUS_ADDRESS"; then
      eval $(dbus-launch --exit-with-session --sh-syntax)
    fi

    export DESKTOP_SESSION=i3
    systemctl --user import-environment PATH DISPLAY XAUTHORITY DESKTOP_SESSION XDG_CONFIG_DIRS XDG_DATA_DIRS XDG_RUNTIME_DIR XDG_SESSION_ID DBUS_SESSION_BUS_ADDRESS
    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
      dbus-update-activation-environment --systemd --all
    fi

    autorandr -c
    xset mouse 1 0
    xset r rate 235 60

    [[ -f "$HOME"/${escapeShellArg config.xsession.scriptPath} ]] \
      && source "$HOME"/${escapeShellArg config.xsession.scriptPath}

    exec i3
  '';

  home.packages = with pkgs; [
    xclip
  ];
}
