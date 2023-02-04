{
  nixpkgs,
  ragenix,
  ...
}:
with nixpkgs.lib; let
  localOverlays =
    mapAttrs'
    (f: _: nameValuePair (removeSuffix ".nix" f) (import (./overlays + "/${f}")))
    (builtins.readDir ./overlays);
in
  localOverlays
  // {
    default =
      composeManyExtensions ((attrValues localOverlays)
        ++ [ragenix.overlays.default]);
  }
