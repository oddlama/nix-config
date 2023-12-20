{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  sqlite,
}:
rustPlatform.buildRustPackage rec {
  pname = "kanidm-secret-manipulator";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "oddlama";
    repo = "kanidm-secret-manipulator";
    rev = "v${version}";
    hash = "sha256-Vv5edTBz5MWHHCWYN5z4KnqPpLZIDTzTcWXnrLBqdgM=";
  };

  cargoHash = "sha256-x/oTiaI4RHdt8pndPhsYQn8PclM0q6RDqTaQ0ODCrh4=";

  nativeBuildInputs = [pkg-config];
  buildInputs = [sqlite];

  meta = with lib; {
    description = "A helper utility that modifies the kanidm database to allow provisioning declarative secrets with NixOS";
    license = licenses.mit;
    maintainers = with maintainers; [oddlama];
    mainProgram = "kanidm-secret-manipulator";
  };
}
