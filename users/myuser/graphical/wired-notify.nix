{pkgs, ...}: {
  systemd.user.services.wired.Unit.ConditionEnvironment = "DISPLAY";
  services.wired = {
    enable = true;
    config = let
      format = pkgs.formats.ron {};
      inherit (format.lib) mkLiteral struct;
      unnamedStruct = struct "";
      Color = hex: struct "Color" {inherit hex;};
      Hook = struct "Hook";
      Vec2 = x: y: struct "Vec2" {inherit x y;};
      Padding = struct "Padding";
      ShortcutsConfig = struct "ShortcutsConfig";
    in
      format.generate "wired.ron" (unnamedStruct {
        max_notifications = 10;
        timeout = 4000;
        poll_interval = 6; # 6ms ~= 166hz.
        history_length = 60;
        replacing_enabled = true;
        replacing_resets_timeout = true;
        min_window_width = 500;
        min_window_height = 100;
        debug = true;

        # https://github.com/Toqozz/wired-notify/wiki/Shortcuts
        shortcuts = ShortcutsConfig {
          notification_interact = 1; # left click
          notification_close = 2; # right click
          notification_action1 = 3; # middle click
        };

        layout_blocks = map unnamedStruct [
          {
            name = "general_root";
            parent = "";
            hook = Hook {
              parent_anchor = mkLiteral "TR";
              self_anchor = mkLiteral "TR";
            };
            offset = Vec2 (-50) 50;
            render_criteria = [];
            params = struct "NotificationBlock" (unnamedStruct {
              monitor = 0;
              border_width = 0;
              border_rounding = 8;
              background_color = Color "#F5F5F5";
              border_color = Color "#00000000";
              border_color_low = Color "#00000000";
              border_color_critical = Color "#FF0000";
              border_color_paused = Color "#00000000";
              gap = Vec2 0.0 8.0;
              notification_hook = Hook {
                parent_anchor = mkLiteral "BM";
                self_anchor = mkLiteral "TM";
              };
            });
          }

          {
            name = "general_notification";
            parent = "general_root";
            hook = Hook {
              parent_anchor = mkLiteral "TM";
              self_anchor = mkLiteral "TM";
            };
            offset = Vec2 0 0;
            params = struct "ImageBlock" (unnamedStruct {
              image_type = mkLiteral "App";
              padding = Padding {
                left = 40;
                right = 40;
                top = 40;
                bottom = 8;
              };
              rounding = 4.0;
              scale_width = 152;
              scale_height = 152;
              filter_mode = mkLiteral "Lanczos3";
            });
          }

          {
            name = "general_summary";
            parent = "general_notification";
            hook = Hook {
              parent_anchor = mkLiteral "BM";
              self_anchor = mkLiteral "TM";
            };
            offset = Vec2 0 12;
            params = struct "TextBlock" (unnamedStruct {
              text = "%s";
              font = "Arial Bold 16";
              ellipsize = mkLiteral "End";
              color = Color "#000000";
              padding = Padding {
                left = 0;
                right = 0;
                top = 0;
                bottom = 0;
              };
              dimensions = unnamedStruct {
                width = unnamedStruct {
                  min = -1;
                  max = 185;
                };
                height = unnamedStruct {
                  min = 0;
                  max = 0;
                };
              };
            });
          }

          {
            name = "general_body";
            parent = "general_summary";
            hook = Hook {
              parent_anchor = mkLiteral "BM";
              self_anchor = mkLiteral "TM";
            };
            offset = Vec2 0 0;
            params = struct "TextBlock" (unnamedStruct {
              text = "%b";
              font = "Arial Bold 16";
              ellipsize = mkLiteral "End";
              color = Color "#000000";
              padding = Padding {
                left = 0;
                right = 0;
                top = 0;
                bottom = 24;
              };
              dimensions = unnamedStruct {
                width = unnamedStruct {
                  min = -1;
                  max = 250;
                };
                height = unnamedStruct {
                  min = 0;
                  max = 0;
                };
              };
            });
          }
        ];
      });

    /*
    {
          name: "app_root",
          parent: "",
          hook: Hook { parent_anchor = mkLiteral "MM"; self_anchor = mkLiteral "MM"; };
          offset: Vec2(x: 0, y: 0),
          render_criteria: [mkLiteral "AppImage"],
          params: NotificationBlock((
                  monitor: 0,
                  border_width: 0,
                  border_rounding: 8,
                  background_color: Color "#F5F5F5",
                  border_color: Color "#00000000",
                  border_color_low: Color "#00000000",
                  border_color_critical: Color "#FF0000",
                  border_color_paused: Color "#00000000",
                  gap: Vec2(x: 0.0, y: 8.0),
                  notification_hook: Hook { parent_anchor = mkLiteral "BM"; self_anchor = mkLiteral "TM"; };
          )),
      ),

      (
          name: "app_notification",
          parent: "app_root",
          hook: Hook { parent_anchor = mkLiteral "TM"; self_anchor = mkLiteral "TM"; };
          offset: Vec2(x: 0, y: 0),
          params: ImageBlock((
                  image_type: App,
                  padding: Padding(left: 40, right: 40, top: 40, bottom: 8),
                  rounding: 4.0,
                  scale_width: 152,
                  scale_height: 152,
                  filter_mode: mkLiteral "Lanczos3",
          )),
      ),

      (
          name: "app_summary",
          parent: "app_notification",
          hook: Hook { parent_anchor = mkLiteral "BM"; self_anchor = mkLiteral "TM"; };
          offset: Vec2(x: 0, y: 12),
          params: TextBlock((
                  text: "%s",
                  font: "Arial Bold 16",
                  ellipsize = mkLiteralEnd,
                  color: Color "#000000",
                  padding: Padding(left: 0, right: 0, top: 0, bottom: 0),
                  dimensions: (width: (min: -1, max: 185), height: (min: 0, max: 0)),
          )),
      ),

      (
          name: "app_body",
          parent: "app_summary",
          hook: Hook { parent_anchor = mkLiteral "BM"; self_anchor = mkLiteral "TM"; };
          offset: Vec2(x: 0, y: 0),
          params: TextBlock((
                  text: "%b",
                  font: "Arial Bold 16",
                  ellipsize = mkLiteralEnd,
                  color: Color "#000000",
                  padding: Padding(left: 0, right: 0, top: 0, bottom: 24),
                  dimensions: (width: (min: -1, max: 250), height: (min: 0, max: 0)),
          )),
      ),

      (
          name: "app_progress",
          parent: "app_notification",
          hook: Hook { parent_anchor = mkLiteral "BM"; self_anchor = mkLiteral "TM"; };
          offset: Vec2(x: 0, y: 50),
          render_criteria: [mkLiteral "Progress"],
          params: ProgressBlock((
                  padding: Padding(left: 0, right: 0, top: 0, bottom: 32),
                  border_width: 2,
                  border_rounding: 2,
                  border_color: Color "#000000",
                  fill_rounding: 1,
                  background_color: Color "#00000000",
                  fill_color: Color "#000000",
                  width: -1.0,
                  height: 30.0,
          )),
      ),

      (
          name: "status_root",
          parent: "",
          hook: Hook { parent_anchor = mkLiteral "TM"; self_anchor = mkLiteral "TM"; };
          offset: Vec2(x: 0.0, y: 60),
          # render_anti_criteria: [AppImage],
          render_criteria: [mkLiteral "HintImage"],
          params: NotificationBlock((
                  monitor: 0,
                  border_width: 0,
                  border_rounding: 8,
                  background_color: Color "#F5F5F5",
                  border_color: Color "#00000000",
                  border_color_low: Color "#00000000",
                  border_color_critical: Color "#FF0000",
                  border_color_paused: Color "#00000000",
                  gap: Vec2(x: 0.0, y: 8.0),
                  notification_hook: Hook { parent_anchor = mkLiteral "BM"; self_anchor = mkLiteral "TM"; };
          )),
      ),

      (
          name: "status_notification",
          parent: "status_root",
          hook: Hook { parent_anchor = mkLiteral "TL"; self_anchor = mkLiteral "TL"; };
          offset: Vec2(x: 0, y: 0),
          params: TextBlock((
                  text: "%s",
                  font: "Arial Bold 16",
                  ellipsize = mkLiteralEnd,
                  color: Color "#000000",
                  padding: Padding(left: 8, right: 8, top: 8, bottom: 8),
                  dimensions: (width: (min: 400, max: 400), height: (min: 84, max: 0)),
          )),
      ),

      (
          name: "status_body",
          parent: "status_notification",
          hook: Hook { parent_anchor = mkLiteral "ML"; self_anchor = mkLiteral "TL"; };
          offset: Vec2(x: 0, y: -24),
          params: TextBlock((
                  text: "%b",
                  font: "Arial 14",
                  ellipsize = mkLiteralEnd,
                  color: Color "#000000",
                  padding: Padding(left: 8, right: 8, top: 8, bottom: 8),
                  dimensions: (width: (min: 400, max: 400), height: (min: 0, max: 84)),
          )),
      ),

      (
          name: "status_image",
          parent: "status_notification",
          hook: Hook { parent_anchor = mkLiteral "TL"; self_anchor = mkLiteral "TR"; };
          offset: Vec2(x: 0, y: 0),
          params: ImageBlock((
                  image_type: Hint,
                  padding: Padding(left: 8, right: 0, top: 8, bottom: 8),
                  rounding: 4.0,
                  scale_width: 84,
                  scale_height: 84,
                  filter_mode: mkLiteral "Lanczos3",
          )),
      ),
    */
  };
}
