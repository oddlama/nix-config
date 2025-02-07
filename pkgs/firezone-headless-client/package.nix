{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
}:
rustPlatform.buildRustPackage rec {
  pname = "firezone-headless-client";
  version = "1.4.0";
  src = fetchFromGitHub {
    owner = "oddlama";
    repo = "firezone";
    rev = "feat/configurable-gateway-interface";
    hash = "sha256-dsGQubRs/ZHdAd6MHpa+3K4vGm4OnCdf1yMlGG1AIJk=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-odrexu5mBGmvHNF4cUu9PDIEdxZC451lWV7dsLYT/Sg=";
  sourceRoot = "${src.name}/rust";
  buildAndTestSubdir = "headless-client";

  # Required to remove profiling arguments which conflict with this builder
  postPatch = ''
    rm .cargo/config.toml
  '';

  # Required to run tests
  preCheck = ''
    export XDG_RUNTIME_DIR=$(mktemp -d)
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "CLI client for the Firezone zero-trust access platform";
    homepage = "https://github.com/firezone/firezone";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      oddlama
      patrickdag
    ];
    mainProgram = "firezone-headless-client";
  };
}
