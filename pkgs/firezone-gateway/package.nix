{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
}:
rustPlatform.buildRustPackage rec {
  pname = "firezone-gateway";
  version = "1.4.2";
  src = fetchFromGitHub {
    owner = "oddlama";
    repo = "firezone";
    rev = "feat/configurable-gateway-interface";
    hash = "sha256-dsGQubRs/ZHdAd6MHpa+3K4vGm4OnCdf1yMlGG1AIJk=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-odrexu5mBGmvHNF4cUu9PDIEdxZC451lWV7dsLYT/Sg=";
  sourceRoot = "${src.name}/rust";
  buildAndTestSubdir = "gateway";

  # Required to remove profiling arguments which conflict with this builder
  postPatch = ''
    rm .cargo/config.toml
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "WireGuard tunnel server for the Firezone zero-trust access platform";
    homepage = "https://github.com/firezone/firezone";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      oddlama
      patrickdag
    ];
    mainProgram = "firezone-gateway";
  };
}
