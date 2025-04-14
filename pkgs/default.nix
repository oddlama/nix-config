_inputs: [
  (import ./scripts)
  (_final: prev: {
    deploy = prev.callPackage ./deploy.nix { };
    git-fuzzy = prev.callPackage ./git-fuzzy { };
    segoe-ui-ttf = prev.callPackage ./segoe-ui-ttf.nix { };
    zsh-histdb-skim = prev.callPackage ./zsh-skim-histdb.nix { };
    neovim-clean = prev.neovim-unwrapped.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
      postInstall = ''
        ${old.postInstall or ""}
        wrapProgram $out/bin/nvim --add-flags "--clean"
      '';
    });
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_pythonFinal: pythonPrev: {
        zha = pythonPrev.zha.overrideAttrs {
          patches = [ ./0000-zha-none-value.patch ];
        };
      })
    ];

    mdns-repeater = prev.callPackage ./mdns-repeater.nix { };

    formats = prev.formats // {
      ron = import ./ron.nix { inherit (prev) lib pkgs; };
    };
  })
]
