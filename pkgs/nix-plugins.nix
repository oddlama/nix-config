{
  lib,
  stdenv,
  fetchFromGitHub,
  nix,
  cmake,
  pkg-config,
  capnproto,
  boost,
  writeText,
}:

let
  patch = writeText "patch" ''
    diff --git a/extra-builtins.cc b/extra-builtins.cc
    index 3a0f90e..bb10f8b 100644
    --- a/extra-builtins.cc
    +++ b/extra-builtins.cc
    @@ -1,10 +1,10 @@
    -#include <config.h>
    -#include <primops.hh>
    -#include <globals.hh>
    -#include <config-global.hh>
    -#include <eval-settings.hh>
    -#include <common-eval-args.hh>
    -#include <filtering-source-accessor.hh>
    +#include <nix/cmd/common-eval-args.hh>
    +#include <nix/expr/eval-settings.hh>
    +#include <nix/expr/primops.hh>
    +#include <nix/fetchers/filtering-source-accessor.hh>
    +#include <nix/store/globals.hh>
    +#include <nix/util/configuration.hh>
    +#include <nix/util/config-global.hh>

     #include "nix-plugins-config.h"
  '';
in

stdenv.mkDerivation rec {
  pname = "nix-plugins";
  version = "15.0.0";

  # src = fetchFromGitHub {
  #   owner = "patrickdag";
  #   repo = "nix-plugins";
  #   rev = "c85627e50bf92807091321029fca3f700c3f13e2";
  #   hash = "sha256-lfQ+tDrNj8+nMw1mUl4ombjxdRpIKmAvcimxN4n1Iyo=";
  # };
  src = fetchFromGitHub {
    owner = "shlevy";
    repo = "nix-plugins";
    tag = version;
    hash = "sha256-C4VqKHi6nVAHuXVhqvTRRyn0Bb619ez4LzgUWPH1cbM=";
  };
  patches = [ patch ];

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    nix
    boost
    capnproto
  ];

  meta = {
    description = "Collection of miscellaneous plugins for the nix expression language";
    homepage = "https://github.com/shlevy/nix-plugins";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
