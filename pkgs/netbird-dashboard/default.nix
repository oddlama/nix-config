{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  inter,
}:
buildNpmPackage rec {
  pname = "netbird-dashboard";
  version = "2.1.3";

  src = fetchFromGitHub {
    owner = "netbirdio";
    repo = "dashboard";
    rev = "v${version}";
    hash = "sha256-RxqGNIo7UdcVKz7UmupjsCzDpaSoz9UawiUc+h2tyTU=";
  };

  patches = [
    ./0001-remove-buildtime-google-fonts.patch
  ];

  CYPRESS_INSTALL_BINARY = 0; # Stops Cypress from trying to download binaries
  npmDepsHash = "sha256-ts3UuThIMf+wwSr3DpZ+k1i9RnHi/ltvhD/7lomVxQk=";
  npmFlags = ["--legacy-peer-deps"];

  preBuild = ''
    cp ${inter}/share/fonts/truetype/InterVariable.ttf src/layouts/inter.ttf
  '';

  installPhase = ''
    cp -R build $out
  '';

  meta = with lib; {
    description = "NetBird Management Service Web UI Panel";
    homepage = "https://github.com/netbirdio/dashboard";
    license = licenses.bsd3;
    maintainers = with maintainers; [thubrecht];
  };
}
