{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  openai,
  pysilero-vad,
}:

buildHomeAssistantComponent rec {
  owner = "NickM-27";
  domain = "local_openai_stt";
  version = "1.3.3";

  src = fetchFromGitHub {
    inherit owner;
    repo = "hass_local_openai_stt";
    rev = version;
    hash = "sha256-So5UHeyW5sm9RYamaCDz4bhHykQokffrKISW8m61YwM=";
  };

  dependencies = [
    openai
    pysilero-vad
  ];

  # Upstream pins 3.0.1, but nixpkgs has a newer API-compatible release.
  ignoreVersionRequirement = [ "pysilero-vad" ];

  meta = {
    changelog = "https://github.com/NickM-27/hass_local_openai_stt/releases/tag/${version}";
    description = "Home Assistant STT integration for local OpenAI-compatible services";
    homepage = "https://github.com/NickM-27/hass_local_openai_stt";
    license = lib.licenses.unfree;
  };
}
