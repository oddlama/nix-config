{
  inputs,
  config,
  minimal,
  ...
}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    verbose = true;
    sharedModules = [
      inputs.nix-index-database.hmModules.nix-index
      inputs.wired-notify.homeManagerModules.default
      {
        home.stateVersion = config.system.stateVersion;
      }
    ];
    extraSpecialArgs = {
      inherit minimal;
    };
  };

  # Required even when using home-manager's zsh module since the /etc/profile load order
  # is partly controlled by this. See nix-community/home-manager#3681.
  # TODO remove once we have nushell
  programs.zsh.enable = true;
}
