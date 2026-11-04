{
  home.persistence."/state".directories = [
    ".cache/noctalia"
    # Settings changed in the UI are stored in settings.toml here, on top of the declarative config.toml
    ".local/state/noctalia"
  ];

  programs.niri.settings = {
    layer-rules = [
      {
        matches = [ { namespace = "^noctalia-wallpaper"; } ];
        place-within-backdrop = true;
      }
    ];

    window-rules = [
      {
        matches = [ { app-id = "^dev\\.noctalia\\.Noctalia$"; } ];
        open-floating = true;
        default-column-width.fixed = 1080;
        default-window-height.fixed = 920;
      }
    ];

    layout = {
      background-color = "transparent";
    };

    overview.workspace-shadow.enable = false;
    debug.honor-xdg-activation-with-invalid-serial = [ ];
  };

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    # Intentionally empty for now: configure via the settings UI, then move the
    # result from ~/.local/state/noctalia/settings.toml into `settings` here.
    settings = { };
  };
}
