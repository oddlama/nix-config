{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchYarnDeps,
  yarnConfigHook,
  yarnBuildHook,
  nodejs,
}:
stdenvNoCC.mkDerivation rec {
  pname = "config-template-card";
  version = "1.3.6-unstable";

  src = fetchFromGitHub {
    owner = "oddlama";
    repo = "config-template-card";
    rev = "517159d1d0aed3d9b7664e832d20a184c52e6e2f";
    hash = "sha256-U+yHjhrFw+6DtADIy7kkAGu3hXdxbgH0kG8Ay6cCAWI=";
  };

  offlineCache = fetchYarnDeps {
    inherit src;
    hash = "sha256-H5vADyspiGSWxBISXWiXvehqFItYDI0PEou42LdqEJU=";
  };

  nativeBuildInputs = [
    yarnConfigHook
    yarnBuildHook
    nodejs
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp dist/* $out

    runHook postInstall
  '';

  meta = {
    description = "Templatable Lovelace Configurations";
    homepage = "https://github.com/oddlama/config-template-card";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    maintainers = with lib.maintainers; [ oddlama ];
  };
}
