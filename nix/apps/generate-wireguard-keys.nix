{
  self,
  pkgs,
  ...
}: let
  inherit (pkgs.lib) escapeShellArg;
in
  pkgs.writeShellScript "generate-wireguard-keys" ''
    set -euo pipefail
    echo TODO
  ''
