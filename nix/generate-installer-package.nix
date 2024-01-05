{self, ...}: nodeName: nodeAttrs: let
  inherit (self.hosts.${nodeName}) system;
  pkgs = self.pkgs.${system};

  disko-script = pkgs.writeShellScriptBin "disko-script" "${nodeAttrs.config.system.build.diskoScript}";
  disko-mount = pkgs.writeShellScriptBin "disko-mount" "${nodeAttrs.config.system.build.mountScript}";
  disko-format = pkgs.writeShellScriptBin "disko-format" "${nodeAttrs.config.system.build.formatScript}";

  install-system = pkgs.writeShellScriptBin "install-system" ''
    set -euo pipefail

    echo "Formatting disks..."
    ${disko-script}/bin/disko-script

    echo "Installing system..."
    nixos-install --no-root-password --system ${nodeAttrs.config.system.build.toplevel}

    echo "Done!"
    echo "[33mDONT FORGET TO EXPORT YOUR ZFS POOL(S)![m"
  '';

  installer-package = pkgs.symlinkJoin {
    name = "installer-package-${nodeName}";
    paths = [
      disko-script
      disko-mount
      disko-format
      install-system
    ];
  };
in {
  # Everything required for the installer as a single package,
  # so it can be used from an existing live system by copying the derivation.
  packages.${system}.installer-package.${nodeName} = installer-package;
}
