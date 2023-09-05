{
  programs.firefox.enable = true;
  home.sessionVariables = {
    MOZ_WEBRENDER = 1;
    # For a better scrolling implementation and touch support.
    # Be sure to also disable "Use smooth scrolling" in about:preferences
    MOZ_USE_XINPUT2 = 1;
    # To allow vaapi access for hardware acceleration
    MOZ_DISABLE_RDD_SANDBOX = 1;
  };

  home.persistence."/state".directories = [
    "Downloads"
  ];

  xdg.mimeApps.defaultApplications = {
    "text/html" = ["firefox.desktop"];
    "text/xml" = ["firefox.desktop"];
    "x-scheme-handler/http" = ["firefox.desktop"];
    "x-scheme-handler/https" = ["firefox.desktop"];
  };
}
