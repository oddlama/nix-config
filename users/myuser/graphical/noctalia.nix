{
  config,
  inputs,
  ...
}:
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;

    # package = perSystem.noctalia.default.override {
    #   quickshell = perSystem.noctalia.quickshell;
    # };

    colors = {
      mError = "#f38ba8"; # red from waybar critical state
      mOnError = "#111111";
      mOnPrimary = "#111111";
      mOnSecondary = "#111111";
      mOnSurface = "#cdd6f4"; # main text color from waybar
      mOnSurfaceVariant = "#828282"; # muted text
      mOnTertiary = "#111111";
      mOutline = "#3c3c3c"; # subtle border
      mPrimary = "#4079d6"; # blue from waybar active workspaces
      mSecondary = "#89b4fa"; # lighter blue accent from waybar
      mShadow = "#000000";
      mSurface = "#111111"; # dark background
      mSurfaceVariant = "#1E1E1E"; # slightly lighter background from waybar
      mTertiary = "#cdd6f4"; # keeping it simple with main text color
      mHover = "#89b4fa";
      mOnHover = "#111111";
    };
    settings = {
      bar = {
        density = "default";
        position = "top";
        backgroundOpacity = 0;
        showCapsule = true;
        floating = true;
        widgets = {
          left = [
            {
              id = "ControlCenter";
              useDistroLogo = true;
            }
            {
              hideUnoccupied = false;
              id = "Workspace";
              labelMode = "none";
            }
            {
              id = "Taskbar";
              onlySameOutput = true;
              onlyActiveWorkspaces = true;
            }
            {
              id = "ActiveWindow";
              showIcon = false;
              scrollingMode = "hover";
              maxWidth = 500;
            }
          ];
          center = [
            {
              id = "MediaMini";
              maxWidth = 500;
              showVisualizer = true;
              showAlbumArt = true;
            }
          ];
          right = [
            {
              id = "Tray";
            }
            {
              id = "CustomButton";
              icon = "calendar";
              textCommand = "noctalia-event";
              textIntervalMs = 60000;
              parseJson = true;
              maxTextLength.horizontal = 43;
            }
            {
              id = "WiFi";
            }
            {
              id = "Bluetooth";
            }
            {
              id = "SystemMonitor";
              showCpuUsage = true;
              showCpuTemp = false;
              showMemoryUsage = true;
              showMemoryAsPercent = true;
              usePrimaryColor = false;
            }
            {
              alwaysShowPercentage = false;
              id = "Battery";
              warningThreshold = 30;
            }
            {
              id = "Volume";
            }
            {
              id = "Microphone";
            }
            {
              formatHorizontal = "dd.MM. HH:mm";
              formatVertical = "HH mm";
              id = "Clock";
              useMonospacedFont = true;
              usePrimaryColor = false;
            }
            {
              id = "KeepAwake";
            }
            {
              id = "NotificationHistory";
              showUnreadBadge = true;
              hideWhenZero = true;
            }
            # {
            #   id = "CustomButton";
            #   icon = "bell";
            #   textCommand = "noctalia-swaync";
            #   textIntervalMs = 2500;
            #   parseJson = true;
            #   leftClickExec = "swaync-client -t -sw";
            #   rightClickExec = "swaync-client -C";
            # }
          ];
        };
      };
      ui = {
        fontDefault = config.user.font;
        fontFixed = config.user.font;
        radiusRatio = 0.3;
      };
      # colorSchemes.predefinedScheme = "Noctalia (default)";
      general = {
        radiusRatio = 0.2;
      };
      wallpaper = {
        enabled = true;
        directory = ../themes;
        defaultWallpaper = ../themes/dark-bg.jpg;
        overviewEnabled = true;
      };
      notifications.enabled = true;
      location = {
        name = "Munich, Germany";
        firstDayOfWeek = 0;
      };
      dock.enabled = false;
    };
  };

  xdg.desktopEntries = {
    caffeine = {
      name = "Caffeine";
      exec = "noctalia-shell ipc call idleInhibitor toggle";
      terminal = false;
      type = "Application";
      categories = [ "Utility" ];
      icon = "caffeine";
    };

    notification-center = {
      name = "Notification Center";
      exec = "noctalia-shell ipc call notifications toggleHistory";
      terminal = false;
      type = "Application";
      categories = [ "Utility" ];
      icon = "notifications";
    };

    clear-notification = {
      name = "Clear Notifications";
      exec = "noctalia-shell ipc call notifications clear";
      terminal = false;
      type = "Application";
      categories = [ "Utility" ];
      icon = "notification-disabled";
    };

    do-not-disturb = {
      name = "Toggle DND";
      exec = "noctalia-shell ipc call notifications toggleDND";
      terminal = false;
      type = "Application";
      categories = [ "Utility" ];
      icon = "notification-disabled";
    };
  };
}
