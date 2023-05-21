{
  imports = [
    ./documentation.nix
  ];

  environment.enableDebugInfo = true;
  repo.defineNixExtraBuiltins = true;
}
