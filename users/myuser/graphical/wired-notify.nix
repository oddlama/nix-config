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
      And = struct "And";
      Or = struct "Or";
      Not = struct "Not";

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

      mkTopBar = name: extra:
        map (x: extra // x) [
          {
            name = "${name}_app_image";
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
            parent = "${name}_app_image";
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
        ];

      mkBody = name: ident: yOffset: summaryRightPadding: extra: let
        maxWFull = 580 - 12;
        maxWImg = maxWFull - 128 - 12;
      in
        map (x: extra // x) (
          [
            {
              name = "${name}_${ident}_hint";
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
              name = "${name}_${ident}_summary";
              parent = "${name}_${ident}_hint";
              hook = mkHook "TR" "TL";
              offset = mkVec2 0 0;
              params = struct "TextBlock" (unnamedStruct {
                text = "%s";
                font = "${fonts.sansSerif.name} Bold ${toString (globalScale * 16)}";
                ellipsize = mkLiteral "End";
                color = colors.base06;
                padding = mkPaddingLrBt 16 16 0 8;
                dimensions = mkDimensionsWH (maxWFull - summaryRightPadding) (maxWFull - summaryRightPadding) 0 30;
                dimensions_image_hint = mkDimensionsWH (maxWImg - summaryRightPadding) (maxWImg - summaryRightPadding) 0 30;
                dimensions_image_both = mkDimensionsWH (maxWImg - summaryRightPadding) (maxWImg - summaryRightPadding) 0 30;
              });
            }
            {
              name = "${name}_${ident}_body";
              parent = "${name}_${ident}_summary";
              hook = mkHook "BL" "TL";
              offset = mkVec2 0 12;
              render_criteria = [
                (And [
                  (Or extra.render_criteria)
                  (mkLiteral "Body")
                ])
              ];
              params = struct "TextBlock" (unnamedStruct {
                text = "%b";
                font = "${fonts.sansSerif.name} ${toString (globalScale * 16)}";
                ellipsize = mkLiteral "End";
                color = colors.base06;
                padding = mkPaddingLrBt 16 16 12 0;
                dimensions = mkDimensionsWH maxWFull maxWFull 0 88;
                dimensions_image_hint = mkDimensionsWH maxWImg maxWImg 0 88;
                dimensions_image_both = mkDimensionsWH maxWImg maxWImg 0 88;
              });
            }
          ]
          # We unfortunately cannot move these out of mkBody, because the depend
          # on the specific name for the parent, which cannot be changed dynamically.
          # So each call to mkBody creates these progress bars which only differ in
          # their parent :/
          ++ (mkProgress name "${ident}_hint" 0 {
            render_criteria = [
              (And (extra.render_criteria
                ++ [
                  (mkLiteral "Progress")
                  (mkLiteral "HintImage")
                ]))
            ];
          })
          ++ (mkProgress name "${ident}_body" 0 {
            render_criteria = [
              (And (extra.render_criteria
                ++ [
                  (mkLiteral "Progress")
                  (mkLiteral "Body")
                  (Not (mkLiteral "HintImage"))
                ]))
            ];
          })
          ++ (mkProgress name "${ident}_summary" 9 {
            render_criteria = [
              (And (extra.render_criteria
                ++ [
                  (mkLiteral "Progress")
                  (mkLiteral "Summary")
                  (Not (Or [
                    (mkLiteral "Body")
                    (mkLiteral "HintImage")
                  ]))
                ]))
            ];
          })
          # Each mkProgress includes a button bar. But if no progress is included in a notification,
          # those won't be rendered, so we have to define bars for non-progress notifications.
          # (And yes, we need 3 because we cannot have duplicate names or dynamic parents)
          ++ (mkButtonBar name "${ident}_hint" {
            render_criteria = [
              (And (extra.render_criteria
                ++ [
                  (Not (mkLiteral "Progress"))
                  (mkLiteral "HintImage")
                ]))
            ];
          })
          ++ (mkButtonBar name "${ident}_body" {
            render_criteria = [
              (And (extra.render_criteria
                ++ [
                  (Not (mkLiteral "Progress"))
                  (mkLiteral "Body")
                  (Not (mkLiteral "HintImage"))
                ]))
            ];
          })
          ++ (mkButtonBar name "${ident}_summary" {
            render_criteria = [
              (And (extra.render_criteria
                ++ [
                  (Not (mkLiteral "Progress"))
                  (mkLiteral "Summary")
                  (Not (Or [
                    (mkLiteral "Body")
                    (mkLiteral "HintImage")
                  ]))
                ]))
            ];
          })
        );

      mkProgress = name: parent: yOffset: extra:
        map (x: extra // x) (
          [
            {
              name = "${name}_progress_${parent}_text";
              parent = "${name}_${parent}";
              hook = mkHook "BL" "TL";
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
              name = "${name}_progress_${parent}_bar";
              parent = "${name}_${parent}";
              hook = mkHook "BL" "TL";
              offset = mkVec2 0 0;
              params = struct "ProgressBlock" (unnamedStruct {
                width = globalScale * 510;
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
          ]
          ++ (mkButtonBar name "progress_${parent}_text" extra)
        );

      mkButtonBar = name: parent: extra:
        map (x: extra // x) [
          {
            name = "${name}_action_0_for_${parent}";
            parent = "${name}_${parent}";
            hook = mkHook "BL" "TL";
            offset = mkVec2 0 0;
            render_criteria = [
              (And (extra.render_criteria
                ++ [
                  (Or [
                    (struct "ActionOther" 0)
                    #(struct "ActionOther" 1)
                    #(struct "ActionOther" 2)
                    #(struct "ActionOther" 3)
                  ])
                ]))
            ];
            params = struct "ButtonBlock" (unnamedStruct {
              text = "%a";
              font = "${fonts.monospace.name} Bold ${toString (globalScale * 14)}";
              ellipsize = mkLiteral "End";
              action = struct "OtherAction" 0;
              text_color = colors.base06;
              text_color_hovered = colors.base06;
              background_color = colors.base01;
              background_color_hovered = colors.base02;
              border_color = colors.base04;
              border_color_hovered = colors.base0F;
              border_rounding = globalScale * 0;
              border_width = globalScale * 2;
              padding = mkPaddingLrBt 12 16 12 0;
              dimensions = mkDimensionsWH 144 48 24 24;
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
          notification_pause = 1;
          notification_close = 2; # right click
          notification_action1 = 3; # middle click
        };

        layout_blocks = let
          criterionHasTopBar = And [
            (mkLiteral "AppImage")
            (Not (Or [
              (struct "AppName" "")
              (struct "AppName" "notify-send")
            ]))
          ];
        in
          map unnamedStruct (lib.flatten [
            (mkRootBlock "general")
            # Time is always shown in the top right corner.
            {
              name = "general_time";
              parent = "general_root";
              hook = mkHook "TR" "TR";
              offset = mkVec2 0 0;
              params = struct "TextBlock" (unnamedStruct {
                color = colors.base05;
                dimensions = mkDimensionsWH 100 100 28 28;
                ellipsize = mkLiteral "End";
                font = "${fonts.monospace.name} Bold ${toString (globalScale * 14)}";
                padding = mkPaddingLrBt 0 16 4 12;
                text = "%t(%a %H:%M)";
              });
            }
            # Top bar for app image, name and time, but only
            # if there is an app name or image.
            (mkTopBar "general" {
              render_criteria = [criterionHasTopBar];
            })
            # if no top bar present: A body with no offset and a summary padding to the right (to not overlay the time)
            (mkBody "general" "notop" 0 (16 + 100) {
              render_criteria = [(Not criterionHasTopBar)];
            })
            # if top bar present: A body with matching y offset and no summary padding to the right
            (mkBody "general" "withtop" 36 0 {
              render_criteria = [criterionHasTopBar];
            })
          ]);
      });
  };
}
