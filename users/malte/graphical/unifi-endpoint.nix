{ lib, nixosConfig, ... }:
lib.mkIf nixosConfig.programs.unifi-endpoint.enable {
  # The app resolves its directories through the XDG base dir variables.
  # Saved credentials go to the secret service (pass-secret-service), not here.
  home.persistence."/persist".directories = [
    ".config/UniFi-Endpoint"
    ".local/share/UniFi-Endpoint"
  ];
  home.persistence."/state".directories = [
    ".local/state/UniFi-Endpoint" # Logs of the app and its user daemon
  ];
}
