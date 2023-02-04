{self, ...}: system:
with self.pkgs.${system};
  mkShell {
    name = "nix-config";

    nativeBuildInputs = [
      # Nix
      cachix
      colmena
      nix-build-uncached
      alejandra
      ragenix
      rnix-lsp
      statix

      # Lua
      stylua
      (luajit.withPackages (p: with p; [luacheck]))
      sumneko-lua-language-server

      # Misc
      shellcheck
      jq
      pre-commit
      rage
    ];

    shellHook = ''
      ${self.checks.${system}.pre-commit-check.shellHook}
    '';
  }
