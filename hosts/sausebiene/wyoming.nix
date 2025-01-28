{
  disabledModules = [
    "services/home-automation/wyoming/faster-whisper.nix"
    "services/home-automation/wyoming/piper.nix"
  ];
  imports = [
    (builtins.trace "remove after next flake update" ./wfw.nix)
    (builtins.trace "remove after next flake update" ./pip.nix)
  ];

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/wyoming";
      mode = "0700";
    }
  ];

  services.wyoming.faster-whisper = {
    servers.hass = {
      enable = true;
      # see https://github.com/rhasspy/rhasspy3/blob/master/programs/asr/faster-whisper/script/download.py
      model = "base-int8";
      language = "de";
      uri = "tcp://0.0.0.0:10300";
      device = "cpu";
    };
  };

  services.wyoming.piper = {
    servers.hass = {
      enable = true;
      # https://rhasspy.github.io/piper-samples/
      voice = "de_DE-thorsten-high";
      uri = "tcp://0.0.0.0:10200";
    };
  };
}
