{
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "segoe-ui";
  version = "unstable-2023-09-04";

  src = fetchFromGitHub {
    owner = "mrbvrz";
    repo = "segoe-ui-linux";
    rev = "73b3a40c6c433d3b8149d945d4c441d4497d5f79";
    hash = "sha256-EwsoX6Rz1uaysCIxL11AHTKb2hfwKi/hNIKgG4MzR5o=";
  };

  installPhase = ''
    mkdir -p $out/share/fonts/truetype
    install -m644 $src/font/*.ttf $out/share/fonts/truetype/
  '';
}
