[
  (import ./caddy.nix)
  (import ./oauth2-proxy)
  (_self: super: {
    kanidm-secret-manipulator = super.callPackage ./kanidm-secret-manipulator.nix {};
    kanidm = super.kanidm.overrideAttrs (_finalAttrs: _previousAttrs: {
      patches = [
        (super.fetchpatch {
          name = "group-list-json-output.patch";
          url = "https://patch-diff.githubusercontent.com/raw/kanidm/kanidm/pull/2016.patch";
          hash = "sha256-gc75KBzhth4fZvuvRa3Rjg1J7DIGy25mzUPCf2aha80=";
        })
        (super.fetchpatch {
          name = "person-and-oauth-json-output.patch";
          url = "https://patch-diff.githubusercontent.com/raw/kanidm/kanidm/pull/2017.patch";
          hash = "sha256-fZgJ7dY2LHvBi64A/6o7kfArUAsLqjWRRpH2q1GL5ic=";
        })
      ];

      doCheck = false;
    });
  })
]
