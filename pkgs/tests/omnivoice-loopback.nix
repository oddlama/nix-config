# CPU-only protocol tests: no CUDA device, model download, or real credentials.
{ pkgs, omnivoice }:
(pkgs.callPackage "${omnivoice}/package.nix" { }).overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ../omnivoice-loopback-no-auth.patch ];
  cargoBuildFlags = [
    "-p"
    "omnivoice-server"
  ];
  cargoTestFlags = [
    "-p"
    "omnivoice-server"
    "--lib"
    "--test"
    "openai_server"
    "--test"
    "wyoming_server"
  ];
  doCheck = true;
})
