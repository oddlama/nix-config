_inputs: [
  (import ./scripts)
  (final: prev: {
    affine-server = prev.callPackage ./affine-server.nix { prisma-engines = final.prisma-engines_6_7; };
    prisma-engines_6_7 = prev.callPackage ./prisma-engines.nix { };
    deploy = prev.callPackage ./deploy.nix { };
    git-fuzzy = prev.callPackage ./git-fuzzy { };
    segoe-ui-ttf = prev.callPackage ./segoe-ui-ttf.nix { };
    zsh-histdb-skim = prev.callPackage ./zsh-skim-histdb.nix { };
    nix-plugins = prev.callPackage ./nix-plugins.nix { };
    part-db = prev.callPackage ./part-db.nix { };
    neovim-clean = prev.neovim-unwrapped.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
      postInstall = ''
        ${old.postInstall or ""}
        wrapProgram $out/bin/nvim --add-flags "--clean"
      '';
    });
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_pythonFinal: pythonPrev: {
        pyhumps = pythonPrev.pyhumps.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            (prev.fetchpatch {
              url = "https://github.com/nficano/humps/commit/f61bb34de152e0cc6904400c573bcf83cfdb67f9.patch";
              hash = "sha256-nLmRRxedpB/O4yVBMY0cqNraDUJ6j7kSBG4J8JKZrrE=";
            })
          ];
        });
      })
    ];
    # pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    #   (pythonFinal: pythonPrev: {
    #     xy = pythonPrev.xy.overrideAttrs { };
    #     foo = pythonFinal.callPackage ./foo.nix { };
    #   })
    # ];
  })
]
