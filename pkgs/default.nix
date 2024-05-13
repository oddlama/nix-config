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
        rev = "v1.0.1";
        hash = "sha256-tSr2I7bGEwJoC5C7BOmru2oh9ta04WVTz449KePYSK4=";
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
    kanidm-provision = prev.callPackage ./kanidm-provision.nix {};
    segoe-ui-ttf = prev.callPackage ./segoe-ui-ttf.nix {};
    zsh-histdb-skim = prev.callPackage ./zsh-skim-histdb.nix {};
    pcsclite_fixed = prev.pcsclite.overrideAttrs (old: {
      postPatch =
        old.postPatch
        + (prev.lib.optionalString (!(prev.lib.strings.hasInfix ''--replace-fail "libpcsclite_real.so.1"'' old.postPatch)) ''
          substituteInPlace src/libredirect.c src/spy/libpcscspy.c \
            --replace-fail "libpcsclite_real.so.1" "$lib/lib/libpcsclite_real.so.1"
        '');
    });
    gnupg = prev.gnupg.override {
      pcsclite = _final.pcsclite_fixed;
    };
    age-plugin-yubikey = prev.age-plugin-yubikey.override {
      pcsclite = _final.pcsclite_fixed;
    };
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
