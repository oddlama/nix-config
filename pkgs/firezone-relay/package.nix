{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
}:
rustPlatform.buildRustPackage rec {
  pname = "firezone-relay";
  version = "unstable-2025-01-19";
  src = fetchFromGitHub {
    owner = "firezone";
    repo = "firezone";
    rev = "8c9427b7b133e5050be34c2ac0e831c12c08f02c";
    hash = "sha256-yccplADHRJQQiKrmHcJ5rvouswHrbx4K6ysnIAoZJR0=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-WpJL5ALFMvyYv3QI5gMazAj6BVr4oyGq+zOo40rxqOE=";
  sourceRoot = "${src.name}/rust";
  buildAndTestSubdir = "relay";

  # Required to remove profiling arguments which conflict with this builder
  postPatch = ''
    rm .cargo/config.toml
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "STUN/TURN server for the Firezone zero-trust access platform";
    homepage = "https://github.com/firezone/firezone";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      oddlama
      patrickdag
    ];
    mainProgram = "firezone-relay";
  };
}
