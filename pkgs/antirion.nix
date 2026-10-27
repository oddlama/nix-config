# Antirion with its embedded web console. No NixOS service is started by this package.
# Usage: pkgs.callPackage ./antirion.nix { }
# Requires recent nixpkgs (pnpm 11 / fetchPnpmDeps v4) and Rust >= 1.98.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  stdenvNoCC,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_11,
  nodejs_24,
  cmake,
  pkg-config,
  perl,
  testers,
}:

assert lib.assertMsg (lib.versionAtLeast rustPlatform.rust.rustc.version "1.98")
  "Antirion requires Rust >= 1.98; pass a newer rustPlatform to callPackage.";

let
  version = "0.1.1";
  # The commit tagged v0.1.1. Keep the binary and frontend build IDs identical.
  rev = "321a35a95b8d7f901164eefb0b63ff7e9a03bde0";
  src = fetchFromGitHub {
    owner = "eliasbiondo";
    repo = "antirion";
    inherit rev;
    hash = "sha256-/kihOfdTKrnn60+MgLi0RzuQ9/zNyH3R1uQq7hK+BUs=";
  };

  console = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "antirion-console";
    inherit version src;
    sourceRoot = "${src.name}/console";

    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs)
        pname
        version
        src
        sourceRoot
        ;
      pnpm = pnpm_11;
      fetcherVersion = 4;
      hash = "sha256-CqvIvlO8mvIW/BxEMN1e19NRAtkUh2iF6j9rgpbDBLA=";
    };

    nativeBuildInputs = [
      nodejs_24
      pnpm_11
      pnpmConfigHook
    ];

    env = {
      NEXT_TELEMETRY_DISABLED = "1";
      ANTIRION_BUILD_COMMIT = rev;
      # Use the packaged pnpm, not an automatically downloaded package manager.
      pnpm_config_pm_on_fail = "ignore";
    };

    # Next's export workers otherwise ignore Nix's parallelism limit.
    postPatch = ''
      substituteInPlace next.config.ts \
        --replace-fail "output: 'export'," \
        "output: 'export', experimental: { cpus: Number(process.env.NIX_BUILD_CORES || 1) },"
    '';

    buildPhase = ''
      runHook preBuild
      export RAYON_NUM_THREADS="$NIX_BUILD_CORES"
      pnpm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      test -s out/index.html
      mkdir -p "$out"
      cp -r out/. "$out/"
      runHook postInstall
    '';
  });
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "antirion";
  inherit version src;

  cargoHash = "sha256-dVM5L056m2Y0T4rj0KmU+nFPVb/xYs0QgzhLAMfY/60=";

  nativeBuildInputs = [
    cmake
    pkg-config
    perl
  ];

  env = {
    ANTIRION_BUILD_COMMIT = rev;
    ANTIRION_CONSOLE_DIR = console;
    # Upstream's fat LTO is memory-intensive; its Compose build uses these too.
    CARGO_PROFILE_RELEASE_LTO = "thin";
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
  };

  cargoBuildFlags = [
    "-p"
    "antirion"
  ];
  # Run the binary package's unit tests, not the workspace's external-service tests.
  cargoTestFlags = [
    "-p"
    "antirion"
    "--lib"
  ];

  postInstall = ''
    install -Dm644 schema/antirion-config.schema.json \
      "$out/share/antirion/config.schema.json"
    install -Dm644 openapi/admin-api.yaml \
      "$out/share/antirion/admin-api.yaml"
    install -Dm644 LICENSE "$out/share/doc/antirion/LICENSE"
    install -Dm644 NOTICE "$out/share/doc/antirion/NOTICE"
  '';

  passthru = {
    inherit console;
    tests.version = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "antirion version";
    };
  };

  meta = {
    description = "Self-hosted AI gateway with API keys, budgets and an embedded web console";
    homepage = "https://github.com/eliasbiondo/antirion";
    changelog = "https://github.com/eliasbiondo/antirion/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "antirion";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
