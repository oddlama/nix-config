{
  self,
  pre-commit-hooks,
  ...
}: system: {
  pre-commit-check =
    pre-commit-hooks.lib.${system}.run
    {
      src = self.pkgs.${system}.lib.cleanSource ../.;
      hooks = {
        alejandra.enable = true;
        statix.enable = true;
        luacheck.enable = true;
        stylua.enable = true;
      };
    };
}
