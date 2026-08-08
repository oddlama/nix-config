inputs: [
  (import ./scripts)
  (
    final: prev:
    let
      pkgs2511 = import inputs.nixpkgs-2511 { inherit (prev.stdenv.hostPlatform) system; };
    in
    {
      affine-server = prev.callPackage ./affine-server.nix {
        prisma-engines = final.prisma-engines_6_8;
        # AFFiNE's yarn.lock is still at version 8. yarn >=4.14 migrates it to version 9,
        # which invalidates the locked checksums and forces a network resolution, so the
        # build needs a yarn from before that change.
        inherit (pkgs2511) yarn-berry_4;
      };
      prisma-engines_6_8 = pkgs2511.callPackage ./prisma-engines.nix { };
      deploy = prev.callPackage ./deploy.nix { };
      git-fuzzy = prev.callPackage ./git-fuzzy { };
      # Nixpkgs dropped libdisplay-info_0_2 on 2026-08-04, but niri-flake still builds
      # niri against the 0.2 ABI and asserts on the exact version. Rebuild it from the
      # generic builder nixpkgs still ships, until niri-flake moves to a newer release.
      libdisplay-info_0_2 =
        prev.lib.warn
          "using local libdisplay-info_0_2 shim; drop it once niri-flake builds against libdisplay-info 0.3/0.4"
          (
            prev.callPackage (import "${inputs.nixpkgs}/pkgs/by-name/li/libdisplay-info/generic.nix" {
              version = "0.2.0";
              hash = "sha256-6xmWBrPHghjok43eIDGeshpUEQTuwWLXNHg7CnBUt3Q=";
            }) { }
          );
      segoe-ui-ttf = prev.callPackage ./segoe-ui-ttf.nix { };
      zsh-histdb-skim = prev.callPackage ./zsh-skim-histdb.nix { };
      nix = prev.nixVersions.nix_2_31;
      nix-plugins = prev.callPackage ./nix-plugins.nix { };
      part-db = prev.callPackage ./part-db.nix { };
      neovim-clean = prev.neovim-unwrapped.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
        postInstall = ''
          ${old.postInstall or ""}
          wrapProgram $out/bin/nvim --add-flags "--clean"
        '';
      });
      # pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      #   (pythonFinal: pythonPrev: {
      #     xy = pythonPrev.xy.overrideAttrs { };
      #     foo = pythonFinal.callPackage ./foo.nix { };
      #   })
      # ];
    }
  )
]
