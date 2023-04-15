{
  inputs,
  pkgs,
  ...
}: {
  environment.etc."nixos/configuration.nix".source = pkgs.writeText "configuration.nix" ''
    assert builtins.trace "This is a dummy config, use colmena!" false;
    { }
  '';

  nix = {
    settings = {
      auto-optimise-store = true;
      allowed-users = ["@wheel"];
      trusted-users = ["root" "@wheel"];
      system-features = ["recursive-nix"];
      substituters = [
        "https://nix-config.cachix.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-config.cachix.org-1:Vd6raEuldeIZpttVQfrUbLvXJHzzzkS0pezXCVVjDG4="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      cores = 0;
      max-jobs = "auto";
    };
    daemonCPUSchedPolicy = "batch";
    daemonIOSchedPriority = 5;
    distributedBuilds = true;
    extraOptions = ''
      builders-use-substitutes = true
      experimental-features = nix-command flakes recursive-nix
      flake-registry = /etc/nix/registry.json
      plugin-files = ${pkgs.nix-plugins}/lib/nix/plugins
      extra-builtins-file = ${../../../nix/extra-builtins.nix}
    '';
    nixPath = ["nixpkgs=/run/current-system/nixpkgs"];
    optimise.automatic = true;
    gc.automatic = true;
    # Define global flakes for this system
    registry = {
      nixpkgs.flake = inputs.nixpkgs;
      p.flake = inputs.nixpkgs;
      pkgs.flake = inputs.nixpkgs;
      templates.flake = inputs.templates;
    };
  };

  system = {
    extraSystemBuilderCmds = ''
      ln -sv ${pkgs.path} $out/nixpkgs
    '';
    stateVersion = "23.05";
  };
}
