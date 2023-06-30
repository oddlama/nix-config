{
  self,
  nixos-generators,
  ...
}: nodeName: nodeAttrs: let
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
  '';

  installer-package = pkgs.symlinkJoin {
    name = "installer-package-${nodeName}";
    paths = with pkgs; [
      disko-script
      disko-mount
      disko-format
      install-system
    ];
  };

  configuration = {
    pkgs,
    lib,
    ...
  }: {
    isoImage.isoName = lib.mkForce "nixos-image-${nodeName}.iso";
    system.stateVersion = nodeAttrs.system.stateVersion;
    nix.extraOptions = ''
      experimental-features = nix-command flakes
    '';

    console.keyMap = "de-latin1-nodeadkeys";

    users.users.root = {
      password = "nixos";
      openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm"];
    };

    environment = {
      variables.EDITOR = "nvim";
      systemPackages = with pkgs; [
        installer-package

        neovim
        git
        tmux
        parted
        ripgrep
        fzf
        wget
        curl
      ];
    };
  };
in {
  packages.${system} = {
    # Everything required for the installer as a single package,
    # so it can be used from an existing live system by copying the derivation.
    # TODO can we use a unified installer iso? does that work regarding size of this package?
    "installer-package-${nodeName}" = installer-package;
    "installer-image-${nodeName}" = nixos-generators.nixosGenerate {
      inherit pkgs;
      modules = [
        configuration
        ../hosts/common/core/ssh.nix
      ];
      format =
        {
          x86_64-linux = "install-iso";
          aarch64-linux = "sd-aarch64-installer";
        }
        .${system};
    };
  };
}
