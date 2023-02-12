{
  description = "oddlama's NixOS Infrastructure";

  inputs = {
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
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
    };

    agenix-rekey.url = "github:oddlama/agenix-rekey";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    templates.url = "github:NixOS/templates";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    colmena,
    nixpkgs,
    flake-utils,
    agenix-rekey,
    ...
  } @ inputs:
    {
      hosts = import ./nix/hosts.nix inputs;
      colmena = import ./nix/colmena.nix inputs;
      overlays = import ./nix/overlay.nix inputs;
      homeConfigurations = import ./nix/home-manager.nix inputs;

      inherit ((colmena.lib.makeHive self.colmena).introspect (x: x)) nodes;
    }
    // flake-utils.lib.eachDefaultSystem (system: rec {
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          self.overlays.default
        ];
        config.allowUnfree = true;
      };

      apps =
        agenix-rekey.defineApps self pkgs self.nodes
        // {
          generate-initrd-keys = flake-utils.mkApp {
            drv = let
              generateHostKey = node: ''
                if [[ ! -f ${node.config.rekey.secrets.initrd_host_ed25519_key.file} ]]; then
                  ssh-keygen -t ed25519 -N "" -f /tmp/1
                  TODO
                fi
              '';
            in
              pkgs.writeShellScript "generate-initrd-keys" ''
                set -euo pipefail
                ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList generateHostKey self.nodes)}
              '';
          };
        };
      checks = import ./nix/checks.nix inputs system;
      devShells.default = import ./nix/dev-shell.nix inputs system;
      formatter = pkgs.alejandra;
    });
}
