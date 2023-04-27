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
  }: {
    system.stateVersion = "23.05";
    nix.extraOptions = ''
      experimental-features = nix-command flakes recursive-nix
    '';

    isoImage.isoName = lib.mkForce "nixos-image-${nodeName}.iso";

    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };

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
        # TODO nodeAttrs.config.boot.system.
      ];
    };
  };
in {
  packages.${system}."installer-image-${nodeName}" = nixos-generators.nixosGenerate {
    pkgs = self.pkgs.${system};
    modules = [configuration];
    format =
      {
        x86_64-linux = "install-iso";
        aarch64-linux = "sd-aarch64-installer";
      }
      .${system};
  };
}
