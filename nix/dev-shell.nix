{self, ...}: system:
with self.pkgs.${system};
  mkShell {
    name = "nix-config";
    packages = [
      # Nix
      cachix
      colmena
      alejandra
      statix
      update-nix-fetchgit

      # Lua
      stylua
      (luajit.withPackages (p: with p; [luacheck]))

      # Misc
      shellcheck
      pre-commit
      rage
    ];

    shellHook = ''
      ${self.checks.${system}.pre-commit-check.shellHook}
    '';
  }
