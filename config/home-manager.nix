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
      inputs.nixos-extra-modules.homeManagerModules.default
      inputs.nix-index-database.hmModules.nix-index
      inputs.nixvim.homeManagerModules.nixvim
      inputs.wired-notify.homeManagerModules.default
      {
        home.stateVersion = config.system.stateVersion;
      }
    ];
    extraSpecialArgs = {
      inherit inputs minimal;
    };
  };

  # Required even when using home-manager's zsh module since the /etc/profile load order
  # is partly controlled by this. See nix-community/home-manager#3681.
  # FIXME: remove once we have nushell
  programs.zsh = {
    enable = true;
    # Disable the completion in the global module because it would call compinit
    # but the home manager config also calls compinit. This causes the cache to be invalidated
    # because the fpath changes in-between, causing constant re-evaluation and thus startup
    # times of 1-2 seconds. Disable the completion here and only keep the home-manager one to fix it.
    enableCompletion = false;
  };
}
