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
  src = ./.;
  cargoHash = "sha256-EAPlI5wZ6ZByafWnCJ199SShtOppErjKyrNHAQIqr/Y=";

  nativeBuildInputs = [pkg-config];
  buildInputs = [sqlite];

  meta = with lib; {
    description = "A helper utility that modifies the kanidm database to allow provisioning declarative secrets with NixOS";
    license = licenses.mit;
    maintainers = with maintainers; [oddlama];
    mainProgram = "kanidm-secret-manipulator";
  };
}
