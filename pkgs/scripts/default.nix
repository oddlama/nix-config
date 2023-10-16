_final: prev: {
  scripts = {
    brightness = prev.callPackage ./brightness.nix {};
    screenshot-area = prev.callPackage ./screenshot-area.nix {};
    screenshot-area-scan-qr = prev.callPackage ./screenshot-area-scan-qr.nix {};
    screenshot-screen = prev.callPackage ./screenshot-screen.nix {};
    volume = prev.callPackage ./volume.nix {};
  };
}
