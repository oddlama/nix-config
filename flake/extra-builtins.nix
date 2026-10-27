# Provides rage decryption via builtins.exec when imported with builtins.
# Requires allow-unsafe-native-code-during-evaluation = true, enabled only
# in the devshell via NIX_CONFIG.
{ exec, ... }:
let
  assertMsg = pred: msg: pred || builtins.throw msg;
  hasSuffix =
    suffix: content:
    let
      lenContent = builtins.stringLength content;
      lenSuffix = builtins.stringLength suffix;
    in
    lenContent >= lenSuffix && builtins.substring (lenContent - lenSuffix) lenContent content == suffix;
in
{
  # Instead of calling rage directly here, we call a wrapper script that will cache the output
  # in /var/tmp/nix-import-encrypted, which allows us to only require the password for each encrypted
  # file once.
  rageImportEncrypted =
    identities: nixFile:
    assert assertMsg (builtins.isPath nixFile)
      "The file to decrypt must be given as a path to prevent impurity.";
    assert assertMsg (hasSuffix ".nix.age" nixFile)
      "The content of the decrypted file must be a nix expression and should therefore end in .nix.age";
    exec (
      [
        ./rage-decrypt-and-cache.sh
        nixFile
      ]
      ++ identities
    );
}
