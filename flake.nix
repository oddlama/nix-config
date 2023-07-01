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
    nixpkgs,
    microvm,
    flake-utils,
    agenix-rekey,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;
  in
    {
      # The identities that are used to rekey agenix secrets and to
      # decrypt all repository-wide secrets.
      secretsConfig = {
        masterIdentities = [./secrets/yk1-nix-rage.pub];
        extraEncryptionPubkeys = [./secrets/backup.pub];
      };

      # This is the list of hosts that this flake defines, plus the minimum
      # amount of metadata that is necessary to instanciate it correctly.
      hosts = let
        nixos = system: {
          type = "nixos";
          inherit system;
        };
      in {
        nom = nixos "x86_64-linux";
        sentinel = nixos "x86_64-linux";
        ward = nixos "x86_64-linux";
        zackbiene = nixos "aarch64-linux";
      };

      # This will process all defined hosts of type "nixos" and
      # generate the required colmena definition for each host.
      # We call the resulting instanciations "nodes".
      # TODO: switch to nixosConfigurations once colmena supports it upstream
      colmena = import ./nix/colmena.nix inputs;
      colmenaNodes = ((colmena.lib.makeHive self.colmena).introspect (x: x)).nodes;

      # True NixOS nodes can define additional microvms (guest nodes) that are built
      # together with the true host. We collect all defined microvm nodes
      # from each node here to allow accessing any node via the unified attribute `nodes`.
      microvmNodes = lib.flip lib.concatMapAttrs self.colmenaNodes (_: node:
        lib.mapAttrs'
        (vm: def: lib.nameValuePair def.nodeName node.config.microvm.vms.${vm}.config)
        (node.config.meta.microvms.vms or {}));

      # All nixosSystem instanciations are collected here, so that we can refer
      # to any system via nodes.<name>
      nodes = self.colmenaNodes // self.microvmNodes;

      # For each true NixOS system, we want to expose an installer image that
      # can be used to do setup on the node.
      inherit
        (lib.foldl' lib.recursiveUpdate {}
          (lib.mapAttrsToList
            (import ./nix/generate-installer.nix inputs)
            self.colmenaNodes))
        packages
        ;
    }
    // flake-utils.lib.eachDefaultSystem (system: rec {
      pkgs = import nixpkgs {
        localSystem = system;
        config.allowUnfree = true;
        overlays =
          import ./lib inputs
          ++ import ./pkgs/default.nix
          ++ [microvm.overlay];
      };

      apps =
        agenix-rekey.defineApps self pkgs self.nodes
        // import ./apps inputs system;
      checks = import ./nix/checks.nix inputs system;
      devShells.default = import ./nix/dev-shell.nix inputs system;
      formatter = pkgs.alejandra;
    });
}
