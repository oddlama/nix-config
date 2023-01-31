{
  description = "oddlama's NixOS Infrastructure";

  inputs = {
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        utils.follows = "flake-utils";
      };
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };

    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.flake-compat.follows = "flake-compat";
    };

    agenix-rekey.url = "github:oddlama/agenix-rekey";
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    templates.url = "github:NixOS/templates";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    agenix-rekey,
    ...
  } @ inputs:
    {
      hosts = import ./nix/hosts.nix;
      deploy = import ./nix/deploy.nix inputs;
      overlays = import ./nix/overlay.nix inputs;
      homeConfigurations = import ./nix/home-manager.nix inputs;
      nixosConfigurations = import ./nix/nixos.nix inputs;
    }
    // flake-utils.lib.eachDefaultSystem (system: rec {
      checks = import ./nix/checks.nix inputs system;
      devShells.default = import ./nix/dev-shell.nix inputs system;

      packages = let
        hostDrvs = import ./nix/host-drvs.nix inputs system;
        default =
          if builtins.hasAttr "${system}" hostDrvs
          then {default = self.packages.${system}.${system};}
          else {};
      in
        hostDrvs // default;

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          self.overlays.default
        ];
        config.allowUnfree = true;
      };

      apps = agenix-rekey.defineApps inputs system;
    });
}
