{
  pkgs,
  nixosConfig,
  ...
}: {
  imports = [
    ./kitty.nix
  ];

  wayland.windowManager.sway = {
    enable = true;
    config =
      {
        modifier = "Mod4";
        terminal = "kitty";

        focus.followMouse = false;
        window.titlebar = false;
        input = {
          "type:keyboard" = {
            repeat_delay = "235";
            repeat_rate = "60";
            xkb_layout = "de";
            xkb_numlock = "enabled";
          };
          "type:pointer" = {
            accel_profile = "flat";
            pointer_accel = "0";
          };
        };
        assigns = {
          "9" = [
            {class = "^steam_app_";}
            {app_id = "^Steam$";}
            {class = "^steam$";}
          ];
        };
        # TODO eww -> bars = [ ];
      }
      # Extra configuration based on which system we are on. It's not ideal to
      # distinguish by node name here, but at least this way it can stay in the
      # sway related config file.
      // {
        potksed = let
          monitorMain = "LG Electronics 27GN950 111NTGYLB719";
          monitorLeft = "LG Electronics LG Ultra HD 0x00077939";
        in {
          output = {
            # TODO "*" = { background = background; };
            ${monitorLeft} = {
              mode = "3840x2160@60Hz";
              pos = "0 0";
              adaptive_sync = "enable";
              subpixel = "rgb";
            };
            ${monitorMain} = {
              mode = "3840x2160@144Hz";
              pos = "3840 0";
              adaptive_sync = "enable";
              subpixel = "rgb";
              render_bit_depth = "10";
            };
          };
          workspaceOutputAssign = [
            {
              workspace = "1";
              output = monitorMain;
            }
            {
              workspace = "7";
              output = monitorLeft;
            }
          ];
        };
      }
      .${nixosConfig.node.name}
      or {};
  };

  home.sessionVariables = {
    # Let nixos electron wrappers enable wayland
    NIXOS_OZONE_WL = 1;
    # Cursor is invisible otherwise
    # XXX: retest in 2024
    WLR_NO_HARDWARE_CURSORS = 1;
    # opengl backend flickers, also vulkan is love.
    WLR_RENDERER = "vulkan";
  };

  home.packages = with pkgs; [
    xdg-utils
    wdisplays
    wl-clipboard
    pinentry # For yubikey
    xdragon
  ];

  # Needed to fix cursors in firefox under wayland, see https://github.com/NixOS/nixpkgs/issues/207339#issuecomment-1374497558
  gtk = {
    enable = true;
    theme = {
      package = pkgs.gnome.gnome-themes-extra;
      name = "Adwaita-dark";
    };
  };
}
