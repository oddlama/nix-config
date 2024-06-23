{
  home.persistence."/state".directories = [
    ".local/state/realtime-stt-server"
  ];

  services.realtime-stt-server.enable = true;
}
