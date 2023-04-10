{
  self,
  pkgs,
  ...
}: let
  inherit (pkgs.lib) escapeShellArg;
in
  # TODO fzf selection of all external peers pls
  pkgs.writeShellScript "generate-wireguard-keys" ''
    set -euo pipefail
    echo TODO
  ''
