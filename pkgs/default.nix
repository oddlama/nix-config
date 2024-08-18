_inputs: [
  (import ./caddy.nix)
  (import ./scripts)
  (_final: prev: {
    deploy = prev.callPackage ./deploy.nix {};
    git-fuzzy = prev.callPackage ./git-fuzzy {};
    stalwart-mail = builtins.trace "remove once 0.9.1 is stable" (prev.callPackage ./stal.nix {});
    delta = builtins.trace "remove once #334814" (prev.delta.overrideAttrs (old: rec {
      version = "0.17.0-unstable-2024-08-12";

      src = prev.fetchFromGitHub {
        owner = "dandavison";
        repo = "delta";
        rev = "a01141b72001f4c630d77cf5274267d7638851e4";
        hash = "sha256-My51pQw5a2Y2VTu39MmnjGfmCavg8pFqOmOntUildS0=";
      };

      cargoDeps = old.cargoDeps.overrideAttrs (_c_old: {
        inherit src;
        outputHash = "sha256-TJ/yLt53hKElylycUfGV8JGt7GzqSnIO3ImhZvhVQu0=";
      });
    }));
    kanidm = prev.kanidm.overrideAttrs (old: let
      provisionSrc = prev.fetchFromGitHub {
        owner = "oddlama";
        repo = "kanidm-provision";
        rev = "v1.1.1";
        hash = "sha256-tX24cszmWu7kB5Eoa3OrPqU1bayD62OpAV12U0ayoEo=";
      };
    in {
      patches =
        old.patches
        ++ [
          "${provisionSrc}/patches/1.3.2-oauth2-basic-secret-modify.patch"
          "${provisionSrc}/patches/1.3.2-recover-account.patch"
        ];
      passthru.enableSecretProvisioning = true;
      doCheck = false;
    });
    awakened-poe-trade = prev.callPackage ./awakened-poe-trade.nix {};
    kanidm-provision = prev.callPackage ./kanidm-provision.nix {};
    segoe-ui-ttf = prev.callPackage ./segoe-ui-ttf.nix {};
    zsh-histdb-skim = prev.callPackage ./zsh-skim-histdb.nix {};
    neovim-clean = prev.neovim-unwrapped.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [prev.makeWrapper];
      postInstall =
        (old.postInstall or "")
        + ''
          wrapProgram $out/bin/nvim --add-flags "--clean"
        '';
    });
    #pythonPackagesExtensions =
    #  prev.pythonPackagesExtensions
    #  ++ [
    #    (_pythonFinal: pythonPrev: {
    #    })
    #  ];

    formats =
      prev.formats
      // {
        ron = import ./ron.nix {inherit (prev) lib pkgs;};
      };
  })
]
