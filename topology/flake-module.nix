{inputs, ...}: {
  imports = [
    inputs.nix-topology.flakeModule
  ];

  perSystem.topology.modules = [./.];
}
