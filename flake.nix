{
  description = "oddlama's NixOS Infrastructure";

  inputs = {
    colmena = {
      url = "github:oddlama/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    lib-net = {
      url = "https://gist.github.com/duairc/5c9bb3c922e5d501a1edb9e7b3b845ba/archive/3885f7cd9ed0a746a9d675da6f265d41e9fd6704.tar.gz";
      flake = false;
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

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    templates.url = "github:NixOS/templates";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    colmena,
    nixos-generators,
    nixpkgs,
    microvm,
    flake-utils,
    agenix-rekey,
    ...
  } @ inputs: let
    recursiveMergeAttrs = nixpkgs.lib.foldl' nixpkgs.lib.recursiveUpdate {};
  in
    {
      extraLib = import ./nix/lib.nix inputs;

      # The identities that are used to rekey agenix secrets and to
      # decrypt all repository-wide secrets.
      secrets = {
        masterIdentities = [./secrets/yk1-nix-rage.pub];
        extraEncryptionPubkeys = [./secrets/backup.pub];
        content = import ./nix/secrets.nix inputs;
      };

      stateVersion = "23.05";

      hosts = {
        nom = {
          type = "nixos";
          system = "x86_64-linux";
        };
        ward = {
          type = "nixos";
          system = "x86_64-linux";
        };
        zackbiene = {
          type = "nixos";
          system = "aarch64-linux";
        };
      };

      colmena = import ./nix/colmena.nix inputs;
      colmenaNodes = ((colmena.lib.makeHive self.colmena).introspect (x: x)).nodes;
      microvmNodes =
        nixpkgs.lib.concatMapAttrs (
          nodeName: nodeAttrs:
            nixpkgs.lib.mapAttrs'
            (n: nixpkgs.lib.nameValuePair "${nodeName}-microvm-${n}")
            (self.colmenaNodes.${nodeName}.config.microvm.vms or {})
        )
        self.colmenaNodes;
      nodes = self.colmenaNodes // self.microvmNodes;

      # Collect installer packages
      inherit
        (recursiveMergeAttrs
          (nixpkgs.lib.mapAttrsToList
            (import ./nix/generate-installer.nix inputs)
            self.nodes))
        packages
        ;
    }
    // flake-utils.lib.eachDefaultSystem (system: rec {
      pkgs = import nixpkgs {
        localSystem = system;
        config.allowUnfree = true;
        overlays = [
          microvm.overlay
        ];
      };

      apps =
        agenix-rekey.defineApps self pkgs self.nodes
        // import ./nix/apps inputs system;
      checks = import ./nix/checks.nix inputs system;
      devShells.default = import ./nix/dev-shell.nix inputs system;
      formatter = pkgs.alejandra;
    });
}
