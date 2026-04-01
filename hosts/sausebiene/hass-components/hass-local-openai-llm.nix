{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  openai,
  demoji,
}:

buildHomeAssistantComponent rec {
  owner = "skye-harris";
  domain = "local_openai";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "skye-harris";
    repo = "hass_local_openai_llm";
    rev = version;
    sha256 = "sha256-fnsn3/MEeSBi6t4/z3jfpsFqw502tDNhoQpnrNqOe5M=";
  };

  dependencies = [
    openai
    demoji
  ];

  meta = {
    changelog = "https://github.com/skye-harris/hass_local_openai_llm/releases/tag/${version}";
    description = "Home Assistant integration for local OpenAI-compatible LLM servers";
    homepage = "https://github.com/skye-harris/hass_local_openai_llm";
    license = lib.licenses.mit;
  };
}
