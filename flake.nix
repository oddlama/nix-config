{
  description = "❄️ oddlama's nix config and dotfiles";

  inputs = {
    agenix = {
      url = "github:ryantm/agenix";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey";
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

    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-extra-modules = {
      url = "github:oddlama/nixos-extra-modules";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
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
      inputs.pre-commit-hooks.follows = "pre-commit-hooks";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
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

  outputs = {
    self,
    agenix-rekey,
    devshell,
    nixos-extra-modules,
    flake-utils,
    nixos-generators,
    nixpkgs,
    pre-commit-hooks,
    ...
  } @ inputs: let
    inherit
      (nixpkgs.lib)
      cleanSource
      foldl'
      mapAttrs
      mapAttrsToList
      recursiveUpdate
      ;
  in
    {
      # The identities that are used to rekey agenix secrets and to
      # decrypt all repository-wide secrets.
      secretsConfig = {
        masterIdentities = [./secrets/yk1-nix-rage.pub];
        extraEncryptionPubkeys = [./secrets/backup.pub];
      };

      agenix-rekey = agenix-rekey.configure {
        userFlake = self;
        inherit (self) nodes pkgs;
      };

      inherit
        (import ./nix/hosts.nix inputs)
        hosts
        guestConfigs
        nixosConfigurations
        nixosConfigurationsMinimal
        ;

      # All nixosSystem instanciations are collected here, so that we can refer
      # to any system via nodes.<name>
      nodes = self.nixosConfigurations // self.guestConfigs;
      # Add a shorthand to easily target toplevel derivations
      "@" = mapAttrs (_: v: v.config.system.build.toplevel) self.nodes;

      # For each true NixOS system, we want to expose an installer package that
      # can be used to do the initial setup on the node from a live environment.
      # We use the minimal sibling configuration to reduce the amount of stuff
      # we have to copy to the live system.
      inherit
        (foldl' recursiveUpdate {}
          (mapAttrsToList
            (import ./nix/generate-installer-package.nix inputs)
            self.nixosConfigurationsMinimal))
        packages
        ;
    }
    // flake-utils.lib.eachDefaultSystem (system: rec {
      apps.setupHetznerStorageBoxes = import (nixos-extra-modules + "/apps/setup-hetzner-storage-boxes.nix") {
        inherit pkgs;
        nixosConfigurations = self.nodes;
        decryptIdentity = builtins.head self.secretsConfig.masterIdentities;
      };

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays =
          import ./lib inputs
          ++ import ./pkgs/default.nix
          ++ [
            nixos-extra-modules.overlays.default
            devshell.overlays.default
            agenix-rekey.overlays.default
          ];
      };

      # XXX: WIP: only testing
      topology =
        import ./topology inputs
        /*
        <-- move into topology flake
        */
        {
          inherit pkgs;
          modules = [
            {
              renderer = "elk";
              nixosConfigurations = self.nodes;

              nodes.internet = {
                name = "Internet";
                deviceType = "internet";
                hardware.image = ./cloud.svg;
                # interfaces.eth0.network = "internet";
                interfaces.eth0.physicalConnections = [
                  {
                    node = "fritzbox";
                    interface = "wan0";
                  }
                  {
                    node = "sentinel";
                    interface = "wan";
                  }
                ];
              };

              nodes.fritzbox = {
                name = "FritzBox";
                deviceType = "router";
                hardware.info = "FRITZ!Box 7520";
                hardware.image = ./fritzbox.png;
                # interfaces.wan0.network = "internet";
                interfaces.wan0 = {};
                interfaces.eth0.physicalConnections = [
                  {
                    node = "ward";
                    interface = "wan";
                  }
                ];
              };

              # TODO: extract from kea!
              networks.home-lan = {
                name = "Home LAN";
                cidrv4 = "192.168.1.0/24";
                #color = "#78dba9";
              };
              networks.home-fritzbox = {
                name = "Home Fritzbox";
                cidrv4 = "192.168.178.0/24";
                #color = "#f1cf8a";
              };

              nodes.ward.interfaces.lan.network = "home-lan";
              nodes.fritzbox.interfaces.eth0.network = "home-fritzbox";

              nodes.switch-attic = {
                name = "Switch Attic";
                deviceType = "switch";
                hardware.info = "D-Link DGS-1016D";
                hardware.image = ./dlink-dgs1016d.png;

                interfaces.eth0.sharesNetworkWith = _: true;
                interfaces.eth1.sharesNetworkWith = _: true;
                interfaces.eth2.sharesNetworkWith = _: true;

                interfaces.eth0.physicalConnections = [
                  {
                    node = "ward";
                    interface = "lan";
                  }
                ];
                interfaces.eth1.physicalConnections = [
                  {
                    node = "sire";
                    interface = "lan";
                  }
                ];
                interfaces.eth2 = {};
              };

              nodes.switch-bedroom-1 = {
                name = "Switch Bedroom 1";
                deviceType = "switch";
                hardware.info = "D-Link DGS-105";
                hardware.image = ./dlink-dgs105.png;

                interfaces.eth0.sharesNetworkWith = _: true;
                interfaces.eth1.sharesNetworkWith = _: true;
                interfaces.eth2.sharesNetworkWith = _: true;

                interfaces.eth0.physicalConnections = [
                  {
                    node = "switch-attic";
                    interface = "eth2";
                  }
                ];
                interfaces.eth1.physicalConnections = [
                  {
                    node = "kroma";
                    interface = "lan1";
                  }
                ];
                interfaces.eth2.physicalConnections = [
                  {
                    node = "nom";
                    interface = "lan1";
                  }
                ];
              };

              #nodes.fritzbox-no-img = {
              #  name = "FritzBox No HImg";
              #  deviceType = "router";
              #  interfaces.wan0.physicalConnections = [
              #    {
              #      node = "ward";
              #      interface = "wan";
              #    }
              #  ];
              #};

              #nodes.fritzbox-device-nd = {
              #  name = "FritzBox No DImg";
              #  deviceType = "device";
              #  hardware.image = ./fritzbox.png;
              #  interfaces.wan0.physicalConnections = [
              #    {
              #      node = "ward";
              #      interface = "wan";
              #    }
              #  ];
              #};

              #nodes.fritzbox-device = {
              #  name = "FritzBox No D&HImg";
              #  deviceType = "device";
              #  interfaces.wan0.physicalConnections = [
              #    {
              #      node = "ward";
              #      interface = "wan";
              #    }
              #  ];
              #};

              # TODO:
              #nodes.fritzbox = config.lib.nodes.mkRouter {};
              #nodes.fritzbox = config.lib.nodes.mkSwitch {};
              #nodes.fritzbox = config.lib.nodes.mkWifiAP {};
              #nodes.printer = config.lib.nodes.mkWifiAP {};
            }
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

      # `nix flake check`
      checks.pre-commit-hooks = pre-commit-hooks.lib.${system}.run {
        src = cleanSource ./.;
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
        packages = [
          pkgs.nix # Always use the nix version from this flake's nixpkgs version, so that nix-plugins (below) doesn't fail because of different nix versions.
        ];

        commands = [
          {
            package = pkgs.deploy;
            help = "Build and deploy this nix config to nodes";
          }
          {
            package = pkgs.agenix-rekey;
            help = "Edit and rekey secrets";
          }
          {
            package = pkgs.alejandra;
            help = "Format nix code";
          }
          {
            package = pkgs.statix;
            help = "Lint nix code";
          }
          {
            package = pkgs.deadnix;
            help = "Find unused expressions in nix code";
          }
          {
            package = pkgs.update-nix-fetchgit;
            help = "Update fetcher hashes inside nix files";
          }
          {
            package = pkgs.nix-tree;
            help = "Interactively browse dependency graphs of Nix derivations";
          }
          {
            package = pkgs.nvd;
            help = "Diff two nix toplevels and show which packages were upgraded";
          }
          {
            package = pkgs.nix-diff;
            help = "Explain why two Nix derivations differ";
          }
          {
            package = pkgs.nix-output-monitor;
            help = "Nix Output Monitor (a drop-in alternative for `nix` which shows a build graph)";
          }
          {
            package = pkgs.writeShellApplication {
              name = "build";
              text = ''
                set -euo pipefail
                [[ "$#" -ge 1 ]] \
                  || { echo "usage: build <HOST>..." >&2; exit 1; }
                HOSTS=()
                for h in "$@"; do
                  HOSTS+=(".#nodes.$h.config.system.build.toplevel")
                done
                nom build --no-link --print-out-paths --show-trace "''${HOSTS[@]}"
              '';
            };
            help = "Build a host configuration";
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
          {
            # Always add files to git after agenix rekey and agenix generate.
            name = "AGENIX_REKEY_ADD_TO_GIT";
            value = "true";
          }
        ];
      };

      # `nix fmt`
      formatter = pkgs.alejandra;
    });
}
