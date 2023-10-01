{
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
        dbus.send-noti-closed = true;

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

    style = builtins.readFile ./deadd.css;
  };
}
