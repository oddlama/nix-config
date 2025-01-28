{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchNpmDeps,
  npmHooks,
  nodejs,
}:
stdenvNoCC.mkDerivation rec {
  pname = "hui-element";
  version = "unstable-2025-01-28";

  src = fetchFromGitHub {
    owner = "oddlama";
    repo = "lovelace-hui-element";
    rev = "4569a5bf0069de0467c1bf73f0d5cfcff039bc26";
    hash = "sha256-qTGbisJ+AHamzMyn38w8URbO/mQM0cOP4Vwss770/eE=";
  };

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-TiLDwE6JtY+EYe/CjYTo0ZjBtpif19CNggcLpqbkVMo=";
  };

  nativeBuildInputs = [
    npmHooks.npmConfigHook
    nodejs
  ];

  buildPhase = ''
    runHook preBuild

    rm hui-element.js
    npm run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp hui-element.js $out/

    runHook postInstall
  '';

  meta = {
    description = "Use built-in elements in the wrong place";
    homepage = "https://github.com/thomasloven/lovelace-hui-element";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    maintainers = with lib.maintainers; [ oddlama ];
  };
}
