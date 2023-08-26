{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  sqlite,
}:
rustPlatform.buildRustPackage rec {
  pname = "kanidm-secret-manipulator";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "oddlama";
    repo = "kanidm-secret-manipulator";
    rev = "v${version}";
    hash = "sha256-Hn/143YJ0rn9AihuI/wsDlqtnGi/LBzbfdMNTukc34c=";
  };

  cargoHash = "sha256-L//ZtfbOxV6Hf5x5tLAQ52MChSclzJlhI7sZKqvByMo=";

  nativeBuildInputs = [pkg-config];
  buildInputs = [sqlite];

  meta = with lib; {
    description = "A helper utility that modifies the kanidm database to allow provisioning declarative secrets with NixOS";
    license = licenses.mit;
    maintainers = with maintainers; [oddlama];
    mainProgram = "kanidm-secret-manipulator";
  };
}
