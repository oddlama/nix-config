{
  self,
  pre-commit-hooks,
  ...
}: system:
with self.pkgs.${system}; {
  pre-commit-check =
    pre-commit-hooks.lib.${system}.run
    {
      src = lib.cleanSource ../.;
      hooks = {
        alejandra.enable = true;
        statix.enable = true;
        luacheck.enable = true;
        stylua.enable = true;
      };
    };
}
