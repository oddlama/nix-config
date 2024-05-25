{
  config,
  pkgs,
  ...
}: {
  users.users.root = {
    inherit (config.repo.secrets.global.root) hashedPassword;
    openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm"];
    shell = pkgs.zsh;
  };

  # This cannot currently be derived automatically due to a design flaw in nixpkgs.
  environment.persistence."/state".users.root.home = "/root";
  environment.persistence."/persist".users.root.home = "/root";

  home-manager.users.root = {
    imports = [
      ../config
    ];

    home = {
      inherit (config.users.users.root) uid;
      username = config.users.users.root.name;

      packages = with pkgs; [
        neovim
        wireguard-tools
      ];
    };
  };
}
