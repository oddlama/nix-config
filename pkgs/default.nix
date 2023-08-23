[
  (import ./caddy.nix)
  (import ./oauth2-proxy)
  (self: super: {
    kanidm-secret-manipulator = self.callPackage ./kanidm-secret-manipulator.nix {};
  })
]
