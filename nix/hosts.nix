inputs: let
  inherit (inputs) self;
  inherit
    (inputs.nixpkgs.lib)
    concatMapAttrs
    filterAttrs
    flip
    mapAttrs
    mapAttrs'
    nameValuePair
    nixosSystem
    ;

  # Creates a new nixosSystem with the correct specialArgs, pkgs and name definition
  mkHost = {minimal}: name: hostCfg: let
    pkgs = self.pkgs.${hostCfg.system};
  in
    nixosSystem {
      specialArgs = {
        # Use the correct instance lib that has our overlays
        inherit (pkgs) lib;
        inherit (self) nodes;
        inherit inputs minimal;
      };
      modules = [
        {
          # We cannot force the package set via nixpkgs.pkgs and
          # inputs.nixpkgs.nixosModules.readOnlyPkgs, since some nixosModules
          # like nixseparatedebuginfod depend on adding packages via nixpkgs.overlays.
          # So we just mimic the options and overlays defined by the passed pkgs set.
          nixpkgs.hostPlatform = hostCfg.system;
          nixpkgs.overlays = pkgs.overlays;
          nixpkgs.config = pkgs.config;
          node.name = name;
          node.secretsDir = ../hosts/${name}/secrets;
        }
        ../hosts/${name}
      ];
    };

  # Load the list of hosts that this flake defines, which
  # associates the minimum amount of metadata that is necessary
  # to instanciate hosts correctly.
  hosts = builtins.fromTOML (builtins.readFile ../hosts.toml);
  # Get all hosts of type "nixos"
  nixosHosts = filterAttrs (_: x: x.type == "nixos") hosts;
  # Process each nixosHosts declaration and generatea nixosSystem definitions
  nixosConfigurations = flip mapAttrs nixosHosts (mkHost {minimal = false;});
  nixosConfigurationsMinimal = flip mapAttrs nixosHosts (mkHost {minimal = true;});

  # True NixOS nodes can define additional microvms (guest nodes) that are built
  # together with the true host. We collect all defined microvm nodes
  # from each node here to allow accessing any node via the unified attribute `nodes`.
  microvmConfigurations = flip concatMapAttrs self.nixosConfigurations (_: node:
    mapAttrs'
    (vm: def: nameValuePair def.nodeName node.config.microvm.vms.${vm}.config)
    (node.config.meta.microvms.vms or {}));
in {
  inherit
    hosts
    microvmConfigurations
    nixosConfigurations
    nixosConfigurationsMinimal
    ;
}
