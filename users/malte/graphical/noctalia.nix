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
      bar = {
        density = "default";
        position = "bottom";
        backgroundOpacity = 0;
        showCapsule = true;
        floating = true;
      };
    };
  };
}
