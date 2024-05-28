{
  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    elewrap = {
      url = "github:oddlama/elewrap";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-extra-modules = {
      url = "github:oddlama/nixos-extra-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-nftables-firewall = {
      url = "github:thelegy/nixos-nftables-firewall";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    templates.url = "github:NixOS/templates";

    wired-notify = {
      url = "github:Toqozz/wired-notify";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devshell.flakeModule
        inputs.pre-commit-hooks.flakeModule
        ./nix/devshell.nix
        ./nix/agenix-rekey.nix
        ./nix/globals.nix
        (
          {
            lib,
            flake-parts-lib,
            ...
          }:
            flake-parts-lib.mkTransposedPerSystemModule {
              name = "images";
              file = ./flake.nix;
              option = lib.mkOption {
                type = lib.types.unspecified;
              };
            }
        )
        (
          {
            lib,
            flake-parts-lib,
            ...
          }:
            flake-parts-lib.mkTransposedPerSystemModule {
              name = "pkgs";
              file = ./flake.nix;
              option = lib.mkOption {
                type = lib.types.unspecified;
              };
            }
        )
      ];

      flake = {
        config,
        lib,
        ...
      }: let
        inherit
          (lib)
          foldl'
          mapAttrs
          mapAttrsToList
          recursiveUpdate
          ;
      in {
        inherit
          (import ./nix/hosts.nix inputs)
          hosts
          guestConfigs
          nixosConfigurations
          nixosConfigurationsMinimal
          ;

        # All nixosSystem instanciations are collected here, so that we can refer
        # to any system via nodes.<name>
        nodes = config.nixosConfigurations // config.guestConfigs;
        # Add a shorthand to easily target toplevel derivations
        "@" = mapAttrs (_: v: v.config.system.build.toplevel) config.nodes;

        # For each true NixOS system, we want to expose an installer package that
        # can be used to do the initial setup on the node from a live environment.
        # We use the minimal sibling configuration to reduce the amount of stuff
        # we have to copy to the live system.
        inherit
          (foldl' recursiveUpdate {}
            (mapAttrsToList
              (import ./nix/generate-installer-package.nix inputs)
              config.nixosConfigurationsMinimal))
          packages
          ;
      };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem = {
        config,
        pkgs,
        system,
        ...
      }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays =
            import ./lib inputs
            ++ import ./pkgs/default.nix
            ++ [
              inputs.agenix-rekey.overlays.default
              inputs.devshell.overlays.default
              inputs.nix-topology.overlays.default
              inputs.nixos-extra-modules.overlays.default
            ];
        };

        inherit pkgs;

        apps.setupHetznerStorageBoxes = import (inputs.nixos-extra-modules + "/apps/setup-hetzner-storage-boxes.nix") {
          inherit pkgs;
          nixosConfigurations = config.nodes;
          decryptIdentity = builtins.head config.secretsConfig.masterIdentities;
        };

        #topology = import inputs.nix-topology {
        #  inherit pkgs;
        #  modules = [
        #    ./topology
        #    {
        #      inherit (inputs.self) nixosConfigurations;
        #    }
        #  ];
        #};

        # For each major system, we provide a customized installer image that
        # has ssh and some other convenience stuff preconfigured.
        # Not strictly necessary for new setups.
        images.live-iso = inputs.nixos-generators.nixosGenerate {
          inherit pkgs;
          modules = [
            ./nix/installer-configuration.nix
            ./config/ssh.nix
          ];
          format =
            {
              x86_64-linux = "install-iso";
              aarch64-linux = "sd-aarch64-installer";
            }
            .${system};
        };
      };
    };
}
