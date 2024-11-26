{
  config,
  lib,
  pkgs,
  ...
}:
let
  disko-script = pkgs.writeShellScriptBin "disko-script" "${config.system.build.diskoScript}";
  disko-mount = pkgs.writeShellScriptBin "disko-mount" "${config.system.build.mountScript}";
  disko-format = pkgs.writeShellScriptBin "disko-format" "${config.system.build.formatScript}";

  install-system = pkgs.writeShellScriptBin "install-system" ''
    set -euo pipefail

    echo "Formatting disks..."
    ${disko-script}/bin/disko-script

    echo "Installing system..."
    nixos-install --no-root-password --system ${config.system.build.toplevel}

    echo "Done!"
    echo "[33mDONT FORGET TO EXPORT YOUR ZFS POOL(S)![m"
  '';

  installer-package = pkgs.symlinkJoin {
    name = "installer-package-${config.node.name}";
    paths = [
      disko-script
      disko-mount
      disko-format
      install-system
    ];
  };
in
{
  options.system.build.installFromLive = lib.mkOption {
    type = lib.types.package;
    description = ''
      A single script that can be used from a live system, which will
      format disks and copy the derivation.
    '';
    default = installer-package;
    readOnly = true;
  };
}
