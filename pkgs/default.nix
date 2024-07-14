inputs: [
  (import ./caddy.nix)
  (import ./scripts)
  (_final: prev: {
    deploy = prev.callPackage ./deploy.nix {};
    git-fuzzy = prev.callPackage ./git-fuzzy {};
    kanidm = prev.kanidm.overrideAttrs (old: let
      provisionSrc = prev.fetchFromGitHub {
        owner = "oddlama";
        repo = "kanidm-provision";
        rev = "v1.0.1";
        hash = "sha256-tSr2I7bGEwJoC5C7BOmru2oh9ta04WVTz449KePYSK4=";
      };
    in {
      patches =
        old.patches
        ++ [
          "${provisionSrc}/patches/1.2.0-oauth2-basic-secret-modify.patch"
          "${provisionSrc}/patches/1.2.0-recover-account.patch"
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
    gpu-screen-recorder = prev.callPackage "${inputs.nixpkgs-gpu-screen-recorder}/pkgs/applications/video/gpu-screen-recorder/default.nix" {};
    gpu-screen-recorder-gtk = prev.callPackage "${inputs.nixpkgs-gpu-screen-recorder}/pkgs/applications/video/gpu-screen-recorder/gpu-screen-recorder-gtk.nix" {};
    open-webui = prev.open-webui.override {python3 = prev.python311;};
    pythonPackagesExtensions =
      prev.pythonPackagesExtensions
      ++ [
        (_pythonFinal: pythonPrev: {
          chromadb = pythonPrev.chromadb.overrideAttrs (old: {
            pythonRelaxDeps =
              old.pythonRelaxDeps
              ++ [
                "chroma-hnswlib"
              ];
          });
        })
      ];

    formats =
      prev.formats
      // {
        ron = import ./ron.nix {inherit (prev) lib pkgs;};
      };
  })
]
