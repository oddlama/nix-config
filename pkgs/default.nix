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
    # pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    #   (_pythonFinal: pythonPrev: {
    #     xy = pythonPrev.xy.overrideAttrs { };
    #   })
    # ];
  })
]
