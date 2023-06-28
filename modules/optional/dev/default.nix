{
  imports = [
    ./documentation.nix
    ./yubikey.nix
  ];

  environment.enableDebugInfo = true;
  repo.defineNixExtraBuiltins = true;
}
