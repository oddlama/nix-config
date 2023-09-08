{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatStringsSep escapeShellArg mapAttrsToList;
  env = {
    MOZ_WEBRENDER = 1;
    # For a better scrolling implementation and touch support.
    # Be sure to also disable "Use smooth scrolling" in about:preferences
    MOZ_USE_XINPUT2 = 1;
    # Required for hardware video decoding.
    # See https://github.com/elFarto/nvidia-vaapi-driver?tab=readme-ov-file#firefox
    MOZ_DISABLE_RDD_SANDBOX = 1;
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };
  envStr = concatStringsSep " " (mapAttrsToList (n: v: "${n}=${escapeShellArg v}") env);
in {
  programs.firefox.enable = true;
  programs.firefox.package = pkgs.firefox.overrideAttrs (old: {
    buildCommand =
      old.buildCommand
      + ''
        substituteInPlace $out/bin/firefox \
          --replace "exec -a" ${escapeShellArg envStr}" exec -a"
      '';
  });

  # TODO userChrome
  # TODO settings if they can coexist with non declarative stuff

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
