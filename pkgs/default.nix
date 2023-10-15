[
  (import ./caddy.nix)
  (import ./oauth2-proxy)
  (import ./scripts)
  (_final: prev: {
    deploy = prev.callPackage ./deploy.nix {};
    git-fuzzy = prev.callPackage ./git-fuzzy {};
    kanidm-secret-manipulator = prev.callPackage ./kanidm-secret-manipulator.nix {};
    segoe-ui-ttf = prev.callPackage ./segoe-ui-ttf.nix {};
    zsh-histdb-skim = prev.callPackage ./zsh-skim-histdb.nix {};

    kanidm = prev.kanidm.overrideAttrs (_finalAttrs: _previousAttrs: {
      patches = [
        (prev.fetchpatch {
          name = "group-list-json-output.patch";
          url = "https://patch-diff.githubusercontent.com/raw/kanidm/kanidm/pull/2016.patch";
          hash = "sha256-gc75KBzhth4fZvuvRa3Rjg1J7DIGy25mzUPCf2aha80=";
        })
        (prev.fetchpatch {
          name = "person-and-oauth-json-output.patch";
          url = "https://patch-diff.githubusercontent.com/raw/kanidm/kanidm/pull/2017.patch";
          hash = "sha256-fZgJ7dY2LHvBi64A/6o7kfArUAsLqjWRRpH2q1GL5ic=";
        })
      ];

      doCheck = false;
    });

    formats =
      prev.formats
      // {
        ron = import ./ron.nix {inherit (prev) lib pkgs;};
      };
  })
]
