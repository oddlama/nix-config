{
  self,
  pkgs,
  ...
} @ inputs: let
  inherit
    (pkgs.lib)
    assertMsg
    removePrefix
    hasPrefix
    concatStringsSep
    filterAttrs
    escapeShellArg
    flatten
    mapAttrsToList
    ;

  inherit (self.extraLib) rageEncryptArgs;

  flakeDir = toString self.sourceInfo.outPath;
  relativeToFlake = x: let
    xFile = toString x;
  in
    assert assertMsg (hasPrefix flakeDir xFile) "${xFile} must be a subpath of ${flakeDir}";
      "." + removePrefix flakeDir xFile;

  x = nodeName: nodeCfg:
    mapAttrsToList (_: s: ''
      echo ${escapeShellArg (relativeToFlake s.file)}
    '') (filterAttrs (_: s: s.generate != null) nodeCfg.config.rekey.secrets);
in
  pkgs.writeShellScript "generate-secrets" ''
    set -euo pipefail
    if [[ ! -e flake.nix ]] ; then
      echo "this script must be executed from your flake's root directory." >&2;
      exit 1
    fi
    ${concatStringsSep "\n" (flatten (mapAttrsToList x self.nodes))}
  ''
