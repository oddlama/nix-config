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
    mapAttrs'
    nameValuePair
    ;

  bindWithModifier = mapAttrs' (k: nameValuePair (cfg.modifier + "+" + k));
  cfg = config.xsession.windowManager.i3.config;
in {
  xsession.numlock.enable = true;
  xsession.windowManager.i3 = {
    enable = true;
    config = {
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
          "Shift+s" =
            "exec --no-startup-id "
            + toString (pkgs.writeShellScript "screenshot-area" ''
              set -euo pipefail
              umask 077
              out="/tmp/screenshots.$UID/$(date +"%Y-%m-%dT%H:%M:%S%:z")-selection.png"
              mkdir -p "$(dirname "$out")"
              ${pkgs.maim}/bin/maim --color=.4,.7,1 --bordersize=1.0 --nodecorations=1 --hidecursor --format=png --quality=10 --noopengl --select "$out"
              notification_id=$(${pkgs.libnotify}/bin/notify-send --icon="$out" --print-id --app-name "screenshot-area" "Screenshot Captured" "📋 copied to clipboard\n⌛ Running OCR...")
              ${pkgs.xclip}/bin/xclip -selection clipboard -t image/png < "$out"
              if ${pkgs.tesseract}/bin/tesseract "$out" - -l eng+deu | ${pkgs.xclip}/bin/xclip -selection primary; then
                ${pkgs.libnotify}/bin/notify-send --icon="$out" --replace-id="$notification_id" --app-name "screenshot-area" "Screenshot Captured" "📋 copied to clipboard\n✅ OCR (copied to primary)."
              else
                ${pkgs.libnotify}/bin/notify-send --icon="$out" --replace-id="$notification_id" --app-name "screenshot-area" "Screenshot Captured" "📋 copied to clipboard\n❌ Error while running OCR."
              fi
            '');
          "F11" =
            "exec --no-startup-id "
            # TODO use writeShellApplication for shellcheck
            # TODO --icon=some-qr-image
            + toString (pkgs.writeShellScript "screenshot-area-scan-qr" ''
              set -euo pipefail

              # Create in-memory tmpfile
              TMPFILE=$(mktemp)
              exec 3<>"$TMPFILE"
              rm "$TMPFILE" # still open in-memory as /dev/fd/3
              TMPFILE=/dev/fd/3

              if ${pkgs.maim}/bin/maim --color=.4,.7,1 --bordersize=1.0 --nodecorations=1 --hidecursor --format=png --quality=10 --noopengl --select \
                | ${pkgs.zbar}/bin/zbarimg --xml - > "$TMPFILE"; then
                N=$(${pkgs.yq}/bin/xq -r '.barcodes.source.index.symbol | if type == "array" then length else 1 end' < "$TMPFILE")
                # Append codes Copy data separated by ---
                DATA=$(${pkgs.yq}/bin/xq -r '.barcodes.source.index.symbol | if type == "array" then .[0].data else .data end' < "$TMPFILE")
                for ((i=1;i<N;++i)); do
                  DATA="$DATA"$'\n'"---"$'\n'"$(${pkgs.yq}/bin/xq -r ".barcodes.source.index.symbol[$i].data" < "$TMPFILE")"
                done
                ${pkgs.xclip}/bin/xclip -selection clipboard <<< "$DATA"
                ${pkgs.libnotify}/bin/notify-send --app-name "screenshot-area-scan-qr" "QR Scan" "✅ $N codes detected\\n📋 copied ''${#DATA} bytes"
              else
                case "$?" in
                  "4") ${pkgs.libnotify}/bin/notify-send --app-name "screenshot-area-scan-qr" "QR Scan" "❌ 0 codes detected" ;;
                  *) ${pkgs.libnotify}/bin/notify-send --app-name "screenshot-area-scan-qr" "QR Scan" "❌ Error while processing image: zbarimg exited with code $?" ;;
                esac
              fi
            '');
          "F12" =
            "exec --no-startup-id "
            + toString (pkgs.writeShellScript "screenshot-screen" ''
              set -euo pipefail
              umask 077
              out="${config.xdg.userDirs.pictures}/screenshots/$(date +"%Y-%m-%dT%H:%M:%S%:z")-fullscreen.png"
              mkdir -p "$(dirname "$out")"
              ${pkgs.maim}/bin/maim --hidecursor --format=png --quality=10 --noopengl "$out"
              notification_id=$(${pkgs.libnotify}/bin/notify-send --icon="$out" --print-id --app-name "screenshot-screen" "Screenshot Captured" "💾 saved to $out\n⌛ Running OCR...")
              ${pkgs.tesseract}/bin/tesseract "$out" - -l eng+deu | ${pkgs.xclip}/bin/xclip -selection primary
              if ${pkgs.tesseract}/bin/tesseract "$out" - -l eng+deu | ${pkgs.xclip}/bin/xclip -selection primary; then
                ${pkgs.libnotify}/bin/notify-send --icon="$out" --replace-id="$notification_id" --app-name "screenshot-screen" "Screenshot Captured" "💾 saved to $out\n✅ OCR (copied to primary)."
              else
                ${pkgs.libnotify}/bin/notify-send --icon="$out" --replace-id="$notification_id" --app-name "screenshot-screen" "Screenshot Captured" "💾 saved to $out\n❌ Error while running OCR."
              fi
            '');

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

          "s" = "splitv";
          "v" = "splith";
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

      #assigns = {
      #  "9" = [
      #    {class = "^steam_app_";}
      #    {app_id = "^Steam$";}
      #    {class = "^steam$";}
      #  ];
      #};
      # TODO eww -> bars = [ ];
    };
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

  home.file.".xinitrc".text = ''
    if test -z "$DBUS_SESSION_BUS_ADDRESS"; then
      eval $(dbus-launch --exit-with-session --sh-syntax)
    fi
    systemctl --user import-environment DISPLAY XAUTHORITY

    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
      dbus-update-activation-environment DISPLAY XAUTHORITY
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
