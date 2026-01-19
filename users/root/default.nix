{
  config,
  globals,
  pkgs,
  ...
}:
{
  users.users.root = {
    inherit (globals.root) hashedPassword;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5Uq+CDy5Pmt3If5M6d8K/Q7HArU6sZ7sgoj3T521Wm"
    ];
    shell = pkgs.zsh;
  };

  home-manager.users.root = {
    imports = [
      ../config
    ];

    home = {
      username = config.users.users.root.name;

      packages = with pkgs; [
        neovim
        wireguard-tools
      ];
    };
  };
}
