{
  nixpkgs,
  cellBlock ? "homeConfigurations",
}: let
  l = nixpkgs.lib // builtins;
  inherit (import ./pasteurize.nix {inherit nixpkgs cellBlock;}) cure shake showAssertions;
in
  self: let
    comb = cure self;
    res = name: config: let
      inherit
        (shake config {})
        evaled
        ;
      asserted = showAssertions evaled;
    in {
      # __schema = "v0";
      inherit (asserted) options config;
      inherit (asserted.config.home) activationPackage;
      newsDisplay = evaled.config.news.display;
      newsEntries = l.sort (a: b: a.time > b.time) (
        l.filter (a: a.condition) evaled.config.news.entries
      );
    };
  in
    l.mapAttrs res comb
