{
  fetchFromGitHub,
  rustPlatform,
  sqlite,
}:
rustPlatform.buildRustPackage rec {
  pname = "zsh-histdb-skim";
  version = "0.8.6";

  buildInputs = [ sqlite ];
  src = fetchFromGitHub {
    owner = "m42e";
    repo = "zsh-histdb-skim";
    rev = "v${version}";
    hash = "sha256-lJ2kpIXPHE8qP0EBnLuyvatWMtepBobNAC09e7itGas=";
  };

  cargoHash = "sha256-dqTYJkKnvjzkV124XZHzDV58rjLhNz+Nc3Jj5gSaJas=";

  patchPhase = ''
    substituteInPlace zsh-histdb-skim-vendored.zsh \
      --replace zsh-histdb-skim "$out/bin/zsh-histdb-skim"
  '';

  postInstall = ''
    mkdir -p $out/share/zsh-histdb-skim
    cp zsh-histdb-skim-vendored.zsh $out/share/zsh-histdb-skim/zsh-histdb-skim.plugin.zsh
  '';
}
