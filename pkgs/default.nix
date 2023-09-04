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
    signal-desktop = super.signal-desktop.overrideAttrs (_finalAttrs: _previousAttrs: {
      version = "6.29.1";
      src = super.fetchurl {
        url = "https://updates.signal.org/desktop/apt/pool/s/signal-desktop/signal-desktop_6.29.1_amd64.deb";
        hash = "sha256-QtQVH8cs42vwzJNiq6klaSQO2pmB80OYjzAR4Bibb/s";
      };
    });
  })
]
