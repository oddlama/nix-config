{inputs, ...}: {
  imports = [
    inputs.devshell.flakeModule
    inputs.pre-commit-hooks.flakeModule
  ];

  perSystem = {
    config,
    pkgs,
    ...
  }: {
    pre-commit.settings.hooks = {
      alejandra.enable = true;
      deadnix.enable = true;
      statix.enable = true;
      #gitleaks = {
      #  enable = true;
      #  name = "gitleaks";
      #  entry = "${pkgs.gitleaks}/bin/gitleaks protect --verbose --redact --staged";
      #  language = "system";
      #  pass_filenames = false;
      #};
    };

    devshells.default = {
      packages = [
        pkgs.nix # Always use the nix version from this flake's nixpkgs version, so that nix-plugins (below) doesn't fail because of different nix versions.
      ];

      commands = [
        {
          package = pkgs.deploy;
          help = "Build and deploy this nix config to nodes";
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
                HOSTS+=(".#nixosConfigurations.$h.config.system.build.toplevel")
              done
              nom build --no-link --print-out-paths --show-trace "''${HOSTS[@]}"
            '';
          };
          help = "Build a host configuration";
        }
      ];

      devshell.startup.pre-commit.text = config.pre-commit.installationScript;

      env = [
        {
          # Additionally configure nix-plugins with our extra builtins file.
          # We need this for our repo secrets.
          name = "NIX_CONFIG";
          value = ''
            plugin-files = ${pkgs.nix-plugins}/lib/nix/plugins
            extra-builtins-file = ${./..}/nix/extra-builtins.nix
          '';
        }
      ];
    };

    # `nix fmt`
    formatter = pkgs.alejandra;
  };
}
