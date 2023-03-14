# This file is intended to be used together with pkgs.nix-plugins,
# to provide rage decryption as an additional safe builtin.
#
# Make sure that nix-plugins is installed by adding the following
# statement to your configuration.nix:
#
# ```nix
# {
#   nix.extraOptions = ''
#     plugin-files = ${pkgs.nix-plugins}/lib/nix/plugins
#     # Please adjust path accordingly, or leave this out and alternativaly
#     # pass `--option extra-builtins-file ./extra-builtins.nix` to each invocation
#     extra-builtins-file = ./extra-builtins.nix
#   '';
# }
# ```
{exec, ...}: let
  assertMsg = pred: msg: pred || builtins.throw msg;
  hasSuffix = suffix: content: let
    lenContent = builtins.stringLength content;
    lenSuffix = builtins.stringLength suffix;
  in
    lenContent >= lenSuffix && builtins.substring (lenContent - lenSuffix) lenContent content == suffix;
in {
  rageImportDecrypt = identities: nixFile:
    assert assertMsg (builtins.isPath nixFile) "The file to decrypt must be given as a path to prevent impurity.";
    assert assertMsg (hasSuffix ".nix.age" nixFile) "The content of the decrypted file must be a nix expression and should therefore end in .nix.age";
      exec (["rage" "-d"] ++ (builtins.concatMap (x: ["-i" x]) identities) ++ [nixFile]);
}
