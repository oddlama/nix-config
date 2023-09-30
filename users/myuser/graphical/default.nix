{
  config,
  lib,
  nixosConfig,
  pkgs,
  ...
}: {
  imports =
    [
      ./discord.nix
      ./firefox.nix
      ./kitty.nix
      ./signal.nix
      ./theme.nix
      ./thunderbird.nix
      # XXX: disabled for the time being because gaming under nvidia+wayland has too many bugs
      # XXX: retest this in the future. Problems were flickering under gles, black screens and refresh issues under vulkan, black wine windows.
      # ./sway.nix
      ./i3.nix
    ]
    ++ lib.optionals nixosConfig.graphical.gaming.enable [
      ./games/bottles.nix
      ./games/minecraft.nix
    ];

  services.deadd-notification-center = {
    enable = true;
    settings = {
      ### Margins for notification-center/notifications
      margin-top = 0;
      margin-right = 0;

      ### Margins for notification-center
      margin-bottom = 0;

      ### Width of the notification center/notifications in pixels.
      width = 500;

      ### Command to run at startup. This can be used to setup
      ### button states.
      # startup-command = deadd-notification-center-startup;

      ### Monitor on which the notification center/notifications will be
      ### printed. If "follow-mouse" is set true, this does nothing.
      monitor = 0;

      ### If true, the notification center/notifications will open on the
      ### screen, on which the mouse is. Overrides the "monitor" setting.
      follow-mouse = false;

      notification-center = {
        ### Margin at the top/right/bottom of the notification center in
        ### pixels. This can be used to avoid overlap between the notification
        ### center and bars such as polybar or i3blocks.
        # margin-top = 0;
        # margin-right = 0;
        # margin-bottom = 0;

        ### Width of the notification center in pixels.
        # width = 500;

        ### Monitor on which the notification center will be printed. If
        ### "follow-mouse" is set true, this does nothing.
        # monitor = 0;

        ### If true, the notification center will open on the screen, on which
        ### the mouse is. Overrides the "monitor" setting.
        # follow-mouse = false;

        ### Notification center closes when the mouse leaves it
        hide-on-mouse-leave = true;

        ### If newFirst is set to true, newest notifications appear on the top
        ### of the notification center. Else, notifications stack, from top to
        ### bottom.
        new-first = true;

        ### If true, the transient field in notifications will be ignored,
        ### thus the notification will be persisted in the notification
        ### center anyways
        ignore-transient = false;

        ### Custom buttons in notification center
        #buttons:
        ### Numbers of buttons that can be drawn on a row of the notification
        ### center.
        # buttons-per-row = 5;

        ### Height of buttons in the notification center (in pixels).
        # buttons-height = 60;

        ### Horizontal and vertical margin between each button in the
        ### notification center (in pixels).
        # buttons-margin = 2;

        ### Button actions and labels. For each button you must specify a
        ### label and a command.
        #actions:
        # - label: VPN
        #   command: "sudo vpnToggle"
        # - label: Bluetooth
        #   command: bluetoothToggle
        # - label: Wifi
        #   command: wifiToggle
        # - label: Screensaver
        #   command: screensaverToggle
        # - label: Keyboard
        #   command: keyboardToggle
      };

      notification = {
        use-markup = true;
        parse-html-entities = true;
        dbus.send-noti-closed = false;

        app-icon = {
          guess-icon-from-name = true;
          icon-size = 20;
        };

        image = {
          size = 100;

          ### The margin around the top, bottom, left, and right of
          ### notification images.
          margin-top = 15;
          margin-bottom = 15;
          margin-left = 15;
          margin-right = 0;
        };

        ### Apply modifications to certain notifications:
        ### Each modification rule needs a "match" and either a "modify" or
        ### a "script" entry.
        #modifications:
        ### Match:
        ### Matches the notifications against these rules. If all of the
        ### values (of one modification rule) match, the "modify"/"script"
        ### part is applied.
        # - match:
        ### Possible match criteria:
        # title: "Notification title"
        # body: "Notification body"
        # time: "12:44"
        # app-name: "App name"
        # urgency: "low" # "low", "normal" or "critical"

        # modify:
        ### Possible modifications
        # title: "abc"
        # body: "abc"
        # app-name: "abc"
        # app-icon: "file:///abc.png"
        ### The timeout has three special values:
        ### timeout: 0 -> don't time out at all
        ### timeout: -1 -> use default timeout
        ### timeout: 1 -> don't show as pop-up
        ### timeout: >1 -> milliseconds until timeout
        # timeout: 1
        # margin-right: 10
        # margin-top: 10
        # image: "file:///abc.png"
        # image-size: 10
        # transient: true
        # send-noti-closed: false
        ### Remove action buttons from notifications
        # remove-actions: true
        ### Set the action-icons hint to true, action labels will then
        ### be intergreted as GTK icon names
        # action-icons: true
        ### List of actions, where the even elements (0, 2, ...) are the
        ### action name and the odd elements are the label
        # actions:
        #   - previous
        #   - media-skip-backward
        #   - play
        #   - media-playback-start
        #   - next
        #   - media-skip-forward
        ### Action commands, where the keys (e.g. "play") is the action
        ### name and the value is a program call that should be executed
        ### on action. Prevents sending of the action to the application.
        # action-commands:
        #   play: playerctl play-pause
        #   previous: playerctl previous
        #   next: playerctl next

        ### Add a class-name to the notification container, that can be
        ### used for specific styling of notifications using the
        ### deadd.css file
        # class-name: "abc"

        # - match:
        # app-name: "Chromium"

        ### Instead of modifying a notification directly, a script can be
        ### run, which will receive the notification as JSON on STDIN. It
        ### is expected to return JSON/YAML configuration that defines the
        ### modifications that should be applied. Minimum complete return
        ### value must be '{"modify": {}, "match": {}}'. Always leave the "match"
        ### object empty (technical reasons, i.e. I am lazy).
        # script: "linux-notification-center-parse-chromium"
        #- match:
        #    app-name: "Spotify"
        #  modify:
        #    image-size: 80
        #    timeout: 1
        #    send-noti-closed: true
        #    class-name: "Spotify"
        #    action-icons: true
        #    actions:
        #      - previous
        #      - media-skip-backward
        #      - play
        #      - media-playback-start
        #      - next
        #      - media-skip-forward
        #    action-commands:
        #      play: playerctl play-pause
        #      previous: playerctl previous
        #      next: playerctl next

        # - match:
        #     title: Bildschirmhelligkeit
        #   modify:
        #     image-size: 60
        popup = {
          ### Default timeout used for notifications in milli-seconds.  This can
          ### be overwritten with the "-t" option (or "--expire-time") of the
          ### notify-send command.
          default-timeout = 10000;

          ### Margin above/right/between notifications (in pixels). This can
          ### be used to avoid overlap between notifications and a bar such as
          ### polybar or i3blocks.
          margin-top = 50;
          margin-right = 50;
          margin-between = 20;

          ### Defines after how many lines of text the body will be truncated.
          ### Use 0 if you want to disable truncation.
          max-lines-in-body = 3;

          ### Determines whether the GTK widget that displays the notification body
          ### in the notification popup will be hidden when empty. This is especially
          ### useful for transient notifications that display a progress bar.
          # hide-body-if-empty = false;

          ### Monitor on which the notifications will be
          ### printed. If "follow-mouse" is set true, this does nothing.
          # monitor = 0;

          ### If true, the notifications will open on the
          ### screen, on which the mouse is. Overrides the "monitor" setting.
          # follow-mouse = false;

          click-behavior = {
            ### The mouse button for dismissing a popup. Must be either "mouse1",
            ### "mouse2", "mouse3", "mouse4", or "mouse5"
            dismiss = "mouse1";

            ### The mouse button for opening a popup with the default action.
            ### Must be either "mouse1", "mouse2", "mouse3", "mouse4", or "mouse5"
            default-action = "mouse3";
            #notification.dbus.send-noti-closed = false;
          };
        };
      };
    };

    # Override bad new default color settings
    style = builtins.readFile ./deadd.css;
    #style = builtins.readFile ./deadd-default.css;
  };

  services.dunst = {
    enable = false;
    settings = let
      dunstOpacity = lib.toHexString (((builtins.ceil (config.stylix.opacity.popups * 100)) * 255) / 100);
      colors = config.lib.stylix.colors.withHashtag;
      inherit (config.stylix) fonts;
    in {
      global = {
        separator_color = colors.base02;
        font = "${fonts.monospace.name} ${toString fonts.sizes.popups}";
        #font = "${fonts.sansSerif.name} ${toString fonts.sizes.popups}";
        frame_width = 0;
        corner_radius = 16;
        progress_frame_width = 0;
        follow = "keyboard";
        progress_bar_corner_radius = 12; # TODO scale based on popup text size? dpi? probably dpi... but how... at startup edit?
        offset = "40x40";
        icon_corner_radius = 12;
        history_length = 60;
        padding = 30;
        horizontal_padding = 30;
        vertical_alignment = "top";
        #[global]
        #icon_corner_radius=12
        #icon_path="/run/current-system/sw/share/icons/hicolor/32x32/actions:/run/current-system/sw/share/icons/hicolor/32x32/animations:/run/current-system/sw/share/icons/hicolor/32x32/apps:/run/current-system/sw/share/icons/hicolor/32x32/categories:/run/current-system/sw/share/icons/hicolor/32x32/devices:/run/current-system/sw/share/icons/hicolor/32x32/emblems:/run/current-system/sw/share/icons/hicolor/32x32/emotes:/run/current-system/sw/share/icons/hicolor/32x32/filesystem:/run/current-system/sw/share/icons/hicolor/32x32/intl:/run/current-system/sw/share/icons/hicolor/32x32/legacy:/run/current-system/sw/share/icons/hicolor/32x32/mimetypes:/run/current-system/sw/share/icons/hicolor/32x32/places:/run/current-system/sw/share/icons/hicolor/32x32/status:/run/current-system/sw/share/icons/hicolor/32x32/stock:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/actions:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/animations:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/apps:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/categories:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/devices:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/emblems:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/emotes:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/filesystem:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/intl:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/legacy:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/mimetypes:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/places:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/status:/etc/profiles/per-user/malte/share/icons/hicolor/32x32/stock:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/actions:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/animations:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/apps:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/categories:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/devices:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/emblems:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/emotes:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/filesystem:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/intl:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/legacy:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/mimetypes:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/places:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/status:/nix/store/6yrlqprw4n35502fxjqkaw70hc094aqa-hicolor-icon-theme-0.17/share/icons/hicolor/32x32/stock"
        #progress_bar_corner_radius=12
        #progress_bar_height=20
        #progress_bar_frame_width=0
        #offset = "32x32"
        #width = 600
        #min_icon_size = 100
        #max_icon_size = 100
        #progress_bar_max_width = 600
        #progress_bar_min_width = 600
        #separator_color="#21262e"
        #
        #[urgency_critical]
        #background="#171b20FF"
        #foreground="#b6beca"
        #frame_color="#e05f65"
        #highlight="#70a5eb"
        #
        #[urgency_low]
        #background="#171b20FF"
        #foreground="#b6beca"
        #frame_color="#78dba9"
        #highlight="#70a5eb"
        #
        #[urgency_normal]
        #background="#101419FF"
        #foreground="#b6beca"
        #frame_color="#c68aee"
        #highlight="#70a5eb"
      };

      urgency_low = {
        background = colors.base01 + dunstOpacity;
        foreground = colors.base05;
        frame_color = colors.base0B;
        highlight = colors.base0F;
      };

      urgency_normal = {
        background = colors.base00 + dunstOpacity;
        foreground = colors.base05;
        frame_color = colors.base0E;
        highlight = colors.base0D;
      };

      urgency_critical = {
        background = colors.base01 + dunstOpacity;
        foreground = colors.base05;
        frame_color = colors.base08;
        highlight = colors.base0D;
        follow = "none"; # Always on main monitor
        timeout = 0;
      };
    };
  };

  home = {
    packages = with pkgs; [
      appimage-run
      chromium
      feh
      pinentry # For yubikey
      gamescope
      thunderbird
      xdg-utils
      xdragon
      yt-dlp
      zathura
    ];

    # TODO audible bell in qt pinentry drives me nuts
    # TODO secureboot -> use pam yubikey login
    # TODO keyboard stays lit on poweroff -> add systemd service to disable it on shutdown
    # TODO on neogit close do neotree update
    # TODO kitty terminfo missing with ssh root@localhost
    # TODO nix repl cltr+del doesnt work
    # TODO wrap neovim for kitty hist
    # TODO neovim gitsigns toggle_deleted keybind
    # TODO neovim gitsigns stage hunk shortcut
    # TODO neovim directtly opening file has different syntax
    # TODO neovim reopening file should continue at the previous position
    # TODO thunderbird doesn't use passwords from password command
    # TODO rotating wallpaper
    # TODO thunderbird date time format is wrong even though this is C.utf8
    # TODO yubikey pinentry is curses but should be graphical
    # TODO accounts.concats accounts.calendar
    # TODO test different pinentrys (pinentry gtk?)
    # TODO agenix rekey edit secret should create temp files with same extension
    # TODO mod+f1-4 for left monitor?
    # TODO autostart signal, firefox (both windows), etc.
    # TODO repo secrets caches in /tmp which is removed each reboot and could be improved
    # TODO entering devshell takes some time after reboot
    # TODO screenshot selection/all and copy clipboard
    # TODO screenshot selection/all and save
    # TODO screenshot selection and scan qr and copy clipboard
    # TODO screenshot selection and ocr and copy clipboard
    # TODO sway shortcuts
    # TODO VP9 hardware video decoding blocklisted
    # TODO gpg switch to sk
    # TODO some font icons not showing neovim because removed from nerdfonts, replace with bertter .

    persistence."/state".directories = [
      "Downloads" # config.xdg.userDirs.download (infinite recursion)
    ];

    persistence."/persist".directories = [
      "projects"
      "Pictures" # config.xdg.userDirs.pictures (infinite recursion)
    ];
  };

  xdg.mimeApps.enable = true;
}
