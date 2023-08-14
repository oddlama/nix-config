{
  imports = [
    ./documentation.nix
    ./yubikey.nix
  ];

  environment.enableDebugInfo = true;
}
