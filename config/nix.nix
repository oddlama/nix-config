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
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
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
    };
  };

  system = {
    extraSystemBuilderCmds = ''
      ln -sv ${inputs.nixpkgs} $out/nixpkgs
    '';
    stateVersion = "24.11";
  };
}
