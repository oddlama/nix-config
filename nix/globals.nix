{
  flake = {
    config,
    lib,
    ...
  }: {
    globals = let
      globalsSystem = lib.evalModules {
        prefix = ["globals"];
        modules = [
          ../modules/globals.nix
          ({lib, ...}: {
            globals = lib.mkMerge (
              lib.concatLists (lib.flip lib.mapAttrsToList config.nodes (
                name: cfg:
                  builtins.addErrorContext "while aggregating globals from nixosConfigurations.${name} into flake-level globals:"
                  cfg.config._globalsDefs
              ))
            );
          })
        ];
      };
    in
      globalsSystem.config.globals;
  };
}
