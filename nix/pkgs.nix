{inputs, ...}: {
  imports = [
    (
      {
        lib,
        flake-parts-lib,
        ...
      }:
        flake-parts-lib.mkTransposedPerSystemModule {
          name = "pkgs";
          file = ./pkgs.nix;
          option = lib.mkOption {
            type = lib.types.unspecified;
          };
        }
    )
  ];

  perSystem = {
    pkgs,
    system,
    ...
  }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays =
        import ../pkgs/default.nix
        ++ [
          inputs.nix-topology.overlays.default
          inputs.nixos-extra-modules.overlays.default
        ];
    };

    inherit pkgs;
  };
}
