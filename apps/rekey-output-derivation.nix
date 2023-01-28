pkgs: config:
with pkgs.lib;
  pkgs.stdenv.mkDerivation rec {
    pname = "host-secrets";
    version = "1.0";
    description = "Rekeyed secrets for this host.";

    srcs = mapAttrsToList (_: x: x.file) config.rekey.secrets;
    sourcePath = ".";
    # Required as input to have the derivation rebuild if this changes
    hostPubkey = let
      pubkey = config.rekey.hostPubkey;
    in
      if isPath pubkey
      then readFile pubkey
      else pubkey;

    dontMakeSourcesWritable = true;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''cp -r "/tmp/nix-rekey/${builtins.hashString "sha1" hostPubkey}/." "$out"'';
  }
