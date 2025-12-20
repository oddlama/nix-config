{
  inputs,
  ...
}:
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.niri.settings = {
    layer-rules = [
      {
        matches = [ { namespace = "^noctalia-wallpaper*"; } ];
        place-within-backdrop = true;
      }
    ];

    layout = {
      background-color = "transparent";
    };

    overview.workspace-shadow.enable = false;
    debug.honor-xdg-activation-with-invalid-serial = [ ];
  };

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;

    settings = {
      audio = {
        cavaFrameRate = 60;
      };
      bar = {
        density = "compact";
        marginHorizontal = 0.2;
        marginVertical = 0.1;
        position = "bottom";
        showCapsule = false;
        showOutline = false;
        transparent = false;
        outerCorners = false;
        widgets = {
          center = [
            {
              id = "Tray";
              blacklist = [ ];
              colorizeIcons = false;
              drawerEnabled = false;
              hidePassive = false;
              pinned = [ ];
            }
            {
              id = "Workspace";
              characterCount = 10;
              colorizeIcons = false;
              enableScrollWheel = false;
              followFocusedScreen = false;
              hideUnoccupied = false;
              labelMode = "name";
              showApplications = false;
              showLabelsOnlyWhenOccupied = false;
            }
          ];
          left = [
            {
              id = "ControlCenter";
              colorizeDistroLogo = false;
              colorizeSystemIcon = "none";
              customIconPath = "";
              enableColorization = false;
              icon = "noctalia";
              useDistroLogo = true;
            }
            { id = "WallpaperSelector"; }
            {
              id = "Spacer";
              width = 20;
            }
            {
              id = "SystemMonitor";
              diskPath = "/persist";
              showCpuTemp = true;
              showCpuUsage = true;
              showDiskUsage = true;
              showGpuTemp = true;
              showMemoryAsPercent = true;
              showMemoryUsage = true;
              showNetworkStats = true;
              usePrimaryColor = false;
            }
            {
              id = "AudioVisualizer";
              colorName = "primary";
              hideWhenIdle = false;
              width = 200;
            }
          ];
          right = [
            {
              id = "MediaMini";
              hideMode = "hidden";
              hideWhenIdle = false;
              maxWidth = 145;
              scrollingMode = "hover";
              showAlbumArt = false;
              showArtistFirst = true;
              showProgressRing = true;
              showVisualizer = false;
              useFixedWidth = false;
              visualizerType = "linear";
            }
            {
              id = "Spacer";
              width = 20;
            }
            {
              id = "Microphone";
              displayMode = "alwaysShow";
            }
            {
              id = "Volume";
              displayMode = "alwaysShow";
            }
            {
              id = "Brightness";
              displayMode = "alwaysShow";
            }
            {
              id = "Spacer";
              width = 20;
            }
            {
              id = "Battery";
              displayMode = "alwaysShow";
              showNoctaliaPerformance = false;
              showPowerProfiles = false;
              warningThreshold = 20;
            }
            {
              id = "NotificationHistory";
              hideWhenZero = true;
              showUnreadBadge = true;
            }
            {
              id = "Clock";
              customFont = "";
              formatHorizontal = "ddd dd.MM. HH:mm:ss";
              formatVertical = "HH mm - dd MM";
              useCustomFont = false;
              usePrimaryColor = false;
            }
          ];
        };
      };
      colorSchemes = {
        predefinedScheme = "Ayu";
      };
      general = {
        animationSpeed = 1.5;
        radiusRatio = 0.4;
        shadowDirection = "center";
        shadowOffsetX = 0;
        shadowOffsetY = 0;
        showSessionButtonsOnLockScreen = false;
      };
      location = {
        firstDayOfWeek = 0;
        name = "Munich, Germany";
      };
      systemMonitor = {
        enableNvidiaGpu = true;
      };
      ui = {
        fontDefault = "Segoe UI";
        fontFixed = "JetBrains Mono";
        panelBackgroundOpacity = 1;
      };
      notifications.enabled = true;
      dock.enabled = false;
      wallpaper = {
        directory = "~/.local/share/wallpapers";
        randomEnabled = true;
      };
    };
  };
}
