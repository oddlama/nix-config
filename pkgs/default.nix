[
  (import ./caddy.nix)
  (import ./scripts)
  (_final: prev: {
    deploy = prev.callPackage ./deploy.nix {};
    git-fuzzy = prev.callPackage ./git-fuzzy {};
    kanidm = prev.kanidm.overrideAttrs (old: let
      provisionSrc = prev.fetchFromGitHub {
        owner = "oddlama";
        repo = "kanidm-provision";
        rev = "aa7a1c8ec04622745b385bd3b0462e1878f56b51";
        hash = "sha256-NRolS3l2kARjkhWP7FYUG//KCEiueh48ZrADdCDb9Zg=";
      };
    in {
      patches =
        old.patches
        ++ [
          "${provisionSrc}/patches/${old.version}-oauth2-basic-secret-modify.patch"
          "${provisionSrc}/patches/${old.version}-recover-account.patch"
        ];
      passthru.enableSecretProvisioning = true;
      doCheck = false;
    });
    awakened-poe-trade = prev.callPackage ./awakened-poe-trade.nix {};
    html-to-svg = prev.callPackage ./html-to-svg {};
    kanidm-provision = prev.callPackage ./kanidm-provision.nix {};
    netbird-dashboard = prev.callPackage ./netbird-dashboard {};
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

    formats =
      prev.formats
      // {
        ron = import ./ron.nix {inherit (prev) lib pkgs;};
      };
  })
]
