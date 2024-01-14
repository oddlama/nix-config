self: system: let
  pkgs = self.pkgs.${system};
in {
  type = "app";
  drv = pkgs.writeShellApplication {
    name = "setup-hetzner-storage-boxes";
    text = ''
      set -euo pipefail

    '';
  };
}
