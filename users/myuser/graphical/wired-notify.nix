{
  config,
  lib,
  pkgs,
  ...
}: {
  systemd.user.services.wired.Unit.ConditionEnvironment = "DISPLAY";
  services.wired = {
    enable = true;
    config = let
      inherit (builtins) floor;

      format = pkgs.formats.ron {};
      inherit (format.lib) mkLiteral struct;

      colors = lib.mapAttrs (_: Color) config.lib.stylix.colors.withHashtag;
      inherit (config.stylix) fonts;

      # A global scaling factor to apply to all notifications.
      globalScale = 1.2;

      # Ron format shorthands and helpers
      unnamedStruct = struct "";
      Color = hex: struct "Color" {inherit hex;};
      Hook = struct "Hook";
      Vec2 = x: y: struct "Vec2" {inherit x y;};
      ShortcutsConfig = struct "ShortcutsConfig";

      mkVec2 = x: y: Vec2 (globalScale * x) (globalScale * y);

      mkHook = parent_anchor: self_anchor:
        Hook {
          parent_anchor = mkLiteral parent_anchor;
          self_anchor = mkLiteral self_anchor;
        };

      mkPaddingLrBt = left: right: bottom: top:
        struct "Padding" {
          left = globalScale * left;
          right = globalScale * right;
          bottom = globalScale * bottom;
          top = globalScale * top;
        };

      mkDimensionsWH = minw: maxw: minh: maxh:
        unnamedStruct {
          width = unnamedStruct {
            min = floor (globalScale * minw);
            max = floor (globalScale * maxw);
          };
          height = unnamedStruct {
            min = floor (globalScale * minh);
            max = floor (globalScale * maxh);
          };
        };

      # Reusable blocks
      mkRootBlock = name: {
        name = "${name}_root";
        parent = "";
        hook = mkHook "TR" "TR";
        offset = Vec2 (-50) 50; # Vec2 instead of mkVec2 to not apply scaling.
        params = struct "NotificationBlock" (unnamedStruct {
          monitor = 0;
          border_width = globalScale * 2;
          border_rounding = globalScale * 0;
          background_color = colors.base00;
          border_color = colors.base04;
          border_color_low = colors.base04;
          border_color_critical = colors.base08;
          border_color_paused = colors.base09;
          gap = mkVec2 0 8;
          notification_hook = mkHook "BR" "TR";
        });
      };

      mkTopBar = name: [
        {
          name = "${name}_app_icon";
          parent = "${name}_root";
          hook = mkHook "TL" "TL";
          offset = mkVec2 0 0;
          params = struct "ImageBlock" (unnamedStruct {
            filter_mode = mkLiteral "Lanczos3";
            image_type = mkLiteral "App";
            min_height = floor (globalScale * 24);
            min_width = floor (globalScale * 24);
            padding = mkPaddingLrBt 16 (-8) 6 12;
            rounding = globalScale * 12.0;
            scale_height = floor (globalScale * 24);
            scale_width = floor (globalScale * 24);
          });
        }
        {
          name = "${name}_app_name";
          parent = "${name}_app_icon";
          hook = mkHook "TR" "TL";
          offset = mkVec2 0 0;
          params = struct "TextBlock" (unnamedStruct {
            color = colors.base05;
            dimensions = mkDimensionsWH 350 350 28 28;
            ellipsize = mkLiteral "End";
            font = "${fonts.monospace.name} ${toString (globalScale * 14)}";
            padding = mkPaddingLrBt 16 0 0 12;
            text = "%n";
          });
        }
        {
          name = "${name}_time";
          parent = "${name}_root";
          hook = mkHook "TR" "TR";
          offset = mkVec2 0 0;
          params = struct "TextBlock" (unnamedStruct {
            color = colors.base05;
            dimensions = mkDimensionsWH 0 (-1) 28 28;
            ellipsize = mkLiteral "End";
            font = "${fonts.monospace.name} Bold ${toString (globalScale * 14)}";
            padding = mkPaddingLrBt 0 16 4 12;
            text = "%t(%a %H:%M)";
          });
        }
      ];

      mkBody = name: yOffset: [
        {
          name = "${name}_hint";
          parent = "${name}_root";
          hook = mkHook "TL" "TL";
          offset = mkVec2 0 yOffset;
          params = struct "ImageBlock" (unnamedStruct {
            filter_mode = mkLiteral "Lanczos3";
            image_type = mkLiteral "Hint";
            padding = mkPaddingLrBt 12 0 12 12;
            rounding = globalScale * 9;
            scale_height = floor (globalScale * 128);
            scale_width = floor (globalScale * 128);
          });
        }
        {
          name = "${name}_summary";
          parent = "${name}_hint";
          hook = mkHook "TR" "TL";
          offset = mkVec2 0 0;
          params = struct "TextBlock" (unnamedStruct {
            text = "%s";
            font = "${fonts.sansSerif.name} Bold ${toString (globalScale * 16)}";
            ellipsize = mkLiteral "End";
            color = colors.base06;
            padding = mkPaddingLrBt 16 16 0 8;
            dimensions = mkDimensionsWH 580 580 0 30;
            dimensions_image_hint = mkDimensionsWH 440 440 0 30;
            dimensions_image_both = mkDimensionsWH 440 440 0 30;
          });
        }
        {
          name = "${name}_body";
          parent = "${name}_summary";
          hook = mkHook "BL" "TL";
          offset = mkVec2 0 12;
          render_criteria = [(mkLiteral "Body")];
          params = struct "TextBlock" (unnamedStruct {
            text = "%b";
            font = "${fonts.sansSerif.name} ${toString (globalScale * 16)}";
            ellipsize = mkLiteral "End";
            color = colors.base06;
            padding = mkPaddingLrBt 16 16 12 0;
            dimensions = mkDimensionsWH 580 580 0 88;
            dimensions_image_hint = mkDimensionsWH 440 440 0 88;
            dimensions_image_both = mkDimensionsWH 440 440 0 88;
          });
        }
      ];

      mkProgress = name: yOffset: extra:
        map (x: x // extra) [
          {
            name = "${name}_progress_${toString yOffset}_text";
            parent = "${name}_root";
            hook = mkHook "TL" "TL";
            offset = mkVec2 0 0;
            params = struct "TextBlock" (unnamedStruct {
              text = "%p%";
              font = "${fonts.monospace.name} Bold ${toString (globalScale * 14)}";
              align = mkLiteral "Right";
              ellipsize = mkLiteral "End";
              color = colors.base06;
              padding = mkPaddingLrBt 12 16 12 yOffset;
              dimensions = mkDimensionsWH 48 48 24 24;
            });
          }
          {
            name = "${name}_progress_${toString yOffset}";
            parent = "${name}_root";
            hook = mkHook "TL" "TL";
            offset = mkVec2 0 0;
            params = struct "ProgressBlock" (unnamedStruct {
              width = globalScale * 520;
              height = globalScale * 12;
              border_width = 0.0;
              border_rounding = globalScale * 6;
              border_color = colors.base03;
              background_color = colors.base03;
              fill_color = colors.base0D;
              fill_rounding = globalScale * 6;
              padding = mkPaddingLrBt 68 16 12 (yOffset + 8);
            });
          }
        ];
    in
      format.generate "wired.ron" (unnamedStruct {
        max_notifications = 10;
        timeout = 10000;
        poll_interval = 6; # 6ms ~= 166hz.
        history_length = 60;
        replacing_enabled = true;
        replacing_resets_timeout = true;
        min_window_width = floor (globalScale * 600);
        min_window_height = floor (globalScale * 60);
        debug = false;

        # https://github.com/Toqozz/wired-notify/wiki/Shortcuts
        shortcuts = ShortcutsConfig {
          notification_interact = 1; # left click
          notification_close = 2; # right click
          notification_action1 = 3; # middle click
        };

        layout_blocks = let
          # Progress for body or hint-image notifications
          # must be much closer to the bottom
          bottomProgressCriteria = struct "Or" [
            (mkLiteral "Body")
            (mkLiteral "HintImage")
          ];
        in
          map unnamedStruct (lib.flatten [
            (mkRootBlock "general")
            (mkTopBar "general")
            (mkBody "general" 36)
            (mkProgress "general" 180 {
              render_criteria = [
                (struct "And" [
                  (mkLiteral "Progress")
                  bottomProgressCriteria
                ])
              ];
            })
            (mkProgress "general" 80 {
              render_criteria = [(mkLiteral "Progress")];
              render_anti_criteria = [bottomProgressCriteria];
            })
          ]);
      });
  };
}
