{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  beautifulsoup4,
}:

buildHomeAssistantComponent rec {
  owner = "greghesp";
  domain = "bambu_lab";
  version = "2.2.22";

  src = fetchFromGitHub {
    owner = "greghesp";
    repo = "ha-bambulab";
    rev = "v${version}";
    sha256 = "sha256-JRJ+tfllDuMrtz+5VQL2l5nkhJQXRoNvsvFnrReSZHE=";
  };

  dependencies = [
    beautifulsoup4
  ];

  meta = {
    changelog = "https://github.com/greghesp/ha-bambulab/releases/tag/v${version}";
    description = "A Home Assistant Integration for Bambu Lab Printers";
    homepage = "https://github.com/greghesp/ha-bambulab";
    maintainers = with lib.maintainers; [ oddlama ];
    license = lib.licenses.mit;
  };
}
