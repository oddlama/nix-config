{
  inputs,
  pkgs,
  ...
}: {
  environment.etc."nixos/configuration.nix".source = pkgs.writeText "configuration.nix" ''
    assert builtins.trace "This is a dummy config, please deploy via the flake!" false;
    { }
  '';

  nix = {
    settings = {
      auto-optimise-store = true;
      allowed-users = ["@wheel"];
      trusted-users = ["root"];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://nix-config.cachix.org"
        "https://nixpkgs-wayland.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nix-config.cachix.org-1:Vd6raEuldeIZpttVQfrUbLvXJHzzzkS0pezXCVVjDG4="
        "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      ];
      cores = 0;
      max-jobs = "auto";
    };
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedPriority = 5;
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
      experimental-features = nix-command flakes
      flake-registry = /etc/nix/registry.json
    '';
    nixPath = ["nixpkgs=/run/current-system/nixpkgs"];
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "monthly";
      options = "--delete-older-than 90d";
    };
    # Define global flakes for this system
    registry = rec {
      nixpkgs.flake = inputs.nixpkgs;
      p = nixpkgs;
      templates.flake = inputs.templates;
    };
  };

  system = {
    extraSystemBuilderCmds = ''
      ln -sv ${inputs.nixpkgs} $out/nixpkgs
    '';
    stateVersion = "23.11";
  };
}
