{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "kanidm-provision";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "oddlama";
    repo = "kanidm-provision";
    rev = "v${version}";
    hash = "sha256-tSr2I7bGEwJoC5C7BOmru2oh9ta04WVTz449KePYSK4=";
  };

  cargoHash = "sha256-LRPpAIH+pXThS+HJ63kVbxMMoBgsky1nf99RWarX7/0=";

  meta = with lib; {
    description = "A small utility to help with kanidm provisioning";
    homepage = "https://github.com/oddlama/kanidm-provision";
    license = with licenses; [asl20 mit];
    maintainers = with maintainers; [oddlama];
    mainProgram = "kanidm-provision";
  };
}
