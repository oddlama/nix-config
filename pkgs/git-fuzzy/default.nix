{
  fetchFromGitHub,
  stdenvNoCC,
  lib,
  makeWrapper,
  gitAndTools,
  bat,
  extraPackages ? [],
}: let
  binPath = lib.makeBinPath ([gitAndTools.hub gitAndTools.delta bat] ++ extraPackages);
in
  stdenvNoCC.mkDerivation rec {
    pname = "git-fuzzy";
    version = "unstable-2023-09-18";
    src = fetchFromGitHub {
      owner = "bigH";
      repo = "git-fuzzy";
      rev = "fb02ba3522e19ae1c69be80e2a58561fe2416155";
      hash = "sha256-Eo2TCx3w3SppoXi8RZu8EC1NhLOnL39bFliHDc2YsyM=";
    };

    patches = [
      ./0001-load-git-config.patch
    ];

    postPatch = ''
      for GF_key in $(grep -o -- 'GF_[A-Z0-9_]*' lib/load-configs.sh | sort -u); do
      key=''${GF_key#"GF_"}
      key=''${key,,}
      cat >> lib/load-configs-from-git.sh <<EOF
      if val=\$(git config --get fuzzy.''${key@Q}); then
        $GF_key=\$val
      fi
      EOF
      done
    '';

    nativeBuildInputs = [makeWrapper];
    installPhase = ''
      install -m755 -D ./bin/git-fuzzy $out/bin/git-fuzzy
      install -d "$out/lib"
      cp -r lib "$out/lib/git-fuzzy"
    '';

    postFixup = ''
      sed -i 's%lib_dir="$script_dir/../lib"%lib_dir='"$out"'/lib/git-fuzzy%' $out/bin/git-fuzzy
      wrapProgram "$out/bin/git-fuzzy" --prefix PATH : ${binPath}
    '';

    meta = {
      description = "FZF-based github cli interface";
      homepage = "https://github.com/bigH/git-fuzzy";
      maintainers = with lib.maintainers; [oddlama];
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  }
