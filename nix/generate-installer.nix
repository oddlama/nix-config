{
  self,
  nixos-generators,
  ...
}: nodeName: nodeAttrs: let
  inherit (self.hosts.${nodeName}) system;
  configuration = {
    pkgs,
    lib,
    ...
  }: let
    disko = pkgs.writeShellScriptBin "disko" "${nodeAttrs.config.system.build.disko}";
    disko-mount = pkgs.writeShellScriptBin "disko-mount" "${nodeAttrs.config.system.build.mountScript}";
    disko-format = pkgs.writeShellScriptBin "disko-format" "${nodeAttrs.config.system.build.formatScript}";

    install-system = pkgs.writeShellScriptBin "install-system" ''
      set -euo pipefail

      echo "Formatting disks..."
      ${disko}/bin/disko

      echo "Installing system..."
      nixos-install --no-root-password --system ${nodeAttrs.config.system.build.toplevel}

      echo "Done!"
    '';
  in {
    isoImage.isoName = lib.mkForce "nixos-image-${nodeName}.iso";
    system.stateVersion = "23.05";
    nix.extraOptions = ''
      experimental-features = nix-command flakes recursive-nix
    '';

    console.keyMap = "de-latin1-nodeadkeys";

    users.users.root = {
      password = "nixos";
      openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm"];
    };

    environment = {
      variables.EDITOR = "nvim";
      systemPackages = with pkgs; [
        neovim
        git
        tmux
        parted
        ripgrep
        fzf
        wget
        curl

        disko
        disko-mount
        disko-format
        install-system
      ];
    };
  };
in {
  packages.${system}."installer-image-${nodeName}" = nixos-generators.nixosGenerate {
    pkgs = self.pkgs.${system};
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
}
