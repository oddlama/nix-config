{inputs, ...}: {
  imports = [
    (
      {
        lib,
        flake-parts-lib,
        ...
      }:
        flake-parts-lib.mkTransposedPerSystemModule {
          name = "topology";
          file = ./flake-module.nix;
          option = lib.mkOption {
            type = lib.types.unspecified;
          };
        }
    )
  ];

  perSystem = {pkgs, ...}: {
    topology = import inputs.nix-topology {
      inherit pkgs;
      modules = [
        ./topology
        {
          inherit (inputs.self) nixosConfigurations;
        }
      ];
    };
  };
}
