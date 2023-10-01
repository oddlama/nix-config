{pkgs, ...}: {
  services.picom = {
    enable = true;
    package = pkgs.picom-next;
    backend = "glx";
    # XXX: switch to backend = "xrender"; if glx causes issues
    settings = {
      # Unredirect all windows if a full-screen opaque window is detected, to
      # maximize performance for full-screen windows. Known to cause
      # flickering when redirecting/unredirecting windows.
      unredir-if-possible = true;

      # Use X Sync fence to sync clients' draw calls, to make sure all draw
      # calls are finished before picom starts drawing. Needed on
      # nvidia-drivers with GLX backend for some users.
      xrender-sync-fence = true;
    };
  };
}
