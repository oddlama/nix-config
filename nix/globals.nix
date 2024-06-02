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
    in {
      # Make sure the keys of this attrset are trivially evaluatable to avoid infinite recursion,
      # therefore we inherit relevant attributes from the config.
      inherit (globalsSystem.config.globals) services;
    };
  };
}
