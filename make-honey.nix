{
  colmena,
  nixpkgs,
  cellBlock ? "colmenaConfigurations",
}: let
  l = nixpkgs.lib // builtins;
  inherit (import ./pasteurize.nix {inherit nixpkgs cellBlock;}) pasteurize stir beeOptions;

  colmenaModules = [
    colmena.nixosModules.assertionModule
    colmena.nixosModules.keyChownModule
    colmena.nixosModules.keyServiceModule
    colmena.nixosModules.deploymentOptions
    beeOptions # still present, but we dont care
  ];
in
  self: let
    comb = pasteurize self;
    evalNode = extra: name: config: let
      inherit (stir config) evalConfig system;
    in
      evalConfig {
        inherit system;
        modules = colmenaModules ++ [extra config];
        specialArgs = {inherit name;};
      };
  in
    # Exported attributes
    l.fix (this: {
      __schema = "v0";

      nodes = l.mapAttrs (evalNode {_module.check = true;}) comb;
      toplevel = l.mapAttrs (_: v: v.config.system.build.toplevel) this.nodes;
      deploymentConfig = l.mapAttrs (_: v: v.config.deployment) this.nodes;
      deploymentConfigSelected = names: l.filterAttrs (name: _: l.elem name names) this.deploymentConfig;
      evalSelected = names: l.filterAttrs (name: _: l.elem name names) this.toplevel;
      evalSelectedDrvPaths = names: l.mapAttrs (_: v: v.drvPath) (this.evalSelected names);
      metaConfig = {
        name = "divnix/hive";
        inherit (import ./flake.nix) description;
        machinesFile = null;
        allowApplyAll = false;
      };
      introspect = f:
        f {
          lib = nixpkgs.lib // builtins;
          pkgs = nixpkgs.legacyPackages.${builtins.currentSystem};
          nodes = l.mapAttrs (evalNode {_module.check = false;}) comb;
        };
    })
