{
  description = "oddlama's NixOS Infrastructure";

  inputs = {
    colmena = {
      url = "github:oddlama/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
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

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    lib-net = {
      url = "https://gist.github.com/duairc/5c9bb3c922e5d501a1edb9e7b3b845ba/archive/3885f7cd9ed0a746a9d675da6f265d41e9fd6704.tar.gz";
      flake = false;
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
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

    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixseparatedebuginfod = {
      url = "github:symphorien/nixseparatedebuginfod";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

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
    agenix-rekey,
    colmena,
    devshell,
    elewrap,
    flake-utils,
    microvm,
    nixos-generators,
    nixpkgs,
    nixpkgs-wayland,
    nixseparatedebuginfod,
    pre-commit-hooks,
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

      # Load the list of hosts that this flake defines, which
      # associates the minimum amount of metadata that is necessary
      # to instanciate hosts correctly.
      hosts = builtins.fromTOML (builtins.readFile ./hosts.toml);

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
      # Add a shorthand to easily target toplevel derivations
      "@" = lib.mapAttrs (_: v: v.config.system.build.toplevel) self.nodes;

      # For each true NixOS system, we want to expose an installer package that
      # can be used to do the initial setup on the node from a live environment.
      inherit
        (lib.foldl' lib.recursiveUpdate {}
          (lib.mapAttrsToList
            (import ./nix/generate-installer-package.nix inputs)
            self.colmenaNodes))
        packages
        ;
    }
    // flake-utils.lib.eachDefaultSystem (system: rec {
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays =
          import ./lib inputs
          ++ import ./pkgs/default.nix
          ++ [
            devshell.overlays.default
            elewrap.overlays.default
            microvm.overlay
            nixpkgs-wayland.overlay
            nixseparatedebuginfod.overlays.default
          ];
      };

      # For each major system, we provide a customized installer image that
      # has ssh and some other convenience stuff preconfigured.
      # Not strictly necessary for new setups.
      images.live-iso = nixos-generators.nixosGenerate {
        inherit pkgs;
        modules = [
          ./nix/installer-configuration.nix
          ./modules/config/ssh.nix
        ];
        format =
          {
            x86_64-linux = "install-iso";
            aarch64-linux = "sd-aarch64-installer";
          }
          .${system};
      };

      # Define local apps and apps used for rekeying secrets
      # `nix run .#<app>`
      apps =
        agenix-rekey.defineApps self pkgs self.nodes
        // import ./apps inputs system;

      # `nix flake check`
      checks.pre-commit-hooks = pre-commit-hooks.lib.${system}.run {
        src = lib.cleanSource ./.;
        hooks = {
          # Nix
          alejandra.enable = true;
          deadnix.enable = true;
          statix.enable = true;
          # Lua (for neovim)
          luacheck.enable = true;
          stylua.enable = true;
        };
      };

      # `nix develop`
      devShells.default = pkgs.devshell.mkShell {
        name = "nix-config";
        packages = with pkgs; [
          faketty # Used in my colmena patch to show progress, XXX: should theoretically be propagated automatically from the patch....
          nix # Always use the nix version from this flake's nixpkgs versios, so that nix-plugins (below) doesn't fail because of different nix versions.
        ];

        commands = with pkgs; [
          {
            package = colmena.packages.${system}.colmena;
            help = "Build and deploy this nix config to nodes";
          }
          {
            package = alejandra;
            help = "Format nix code";
          }
          {
            package = statix;
            help = "Lint nix code";
          }
          {
            package = deadnix;
            help = "Find unused expressions in nix code";
          }
          {
            package = update-nix-fetchgit;
            help = "Update fetcher hashes inside nix files";
          }
          {
            package = nix-tree;
            help = "Interactively browse dependency graphs of Nix derivations";
          }
          {
            package = nix-diff;
            help = "Explain why two Nix derivations differ";
          }
        ];

        devshell.startup.pre-commit.text = self.checks.${system}.pre-commit-hooks.shellHook;

        env = [
          {
            # Additionally configure nix-plugins with our extra builtins file.
            # We need this for our repo secrets.
            name = "NIX_CONFIG";
            value = ''
              plugin-files = ${pkgs.nix-plugins}/lib/nix/plugins
              extra-builtins-file = ${self.outPath}/nix/extra-builtins.nix
            '';
          }
        ];
      };

      # `nix fmt`
      formatter = pkgs.alejandra;
    });
}
