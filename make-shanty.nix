{
  nixpkgs,
  cellBlock ? "diskoConfigurations",
}: let
  l = nixpkgs.lib // builtins;
  inherit (import ./pasteurize.nix {inherit nixpkgs cellBlock;}) sing;
in
  sing
