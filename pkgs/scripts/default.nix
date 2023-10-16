_final: prev: {
  scripts = {
    screenshot-area = prev.callPackage ./screenshot-area.nix {};
    screenshot-area-scan-qr = prev.callPackage ./screenshot-area-scan-qr.nix {};
    screenshot-screen = prev.callPackage ./screenshot-screen.nix {};
    volume = prev.callPackage ./volume.nix {};
  };
}
