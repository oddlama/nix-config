{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  cloudscraper,
}:

buildHomeAssistantComponent rec {
  owner = "greghesp";
  domain = "bambu_lab";
  version = "2.0.40";

  src = fetchFromGitHub {
    owner = "greghesp";
    repo = "ha-bambulab";
    rev = "v${version}";
    sha256 = "sha256-ygbNq7B/ZBQ8/al9ADPSru+VpzmMESwxhKA0YkKKOrE=";
  };

  dependencies = [
    cloudscraper
  ];

  meta = {
    changelog = "https://github.com/greghesp/ha-bambulab/releases/tag/v${version}";
    description = "A Home Assistant Integration for Bambu Lab Printers";
    homepage = "https://github.com/greghesp/ha-bambulab";
    maintainers = with lib.maintainers; [ oddlama ];
    license = lib.licenses.mit;
  };
}
