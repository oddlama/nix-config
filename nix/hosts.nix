{inputs, ...}: {
  flake = {
    config,
    lib,
    ...
  }: let
    inherit
      (lib)
      concatMapAttrs
      filterAttrs
      flip
      genAttrs
      mapAttrs
      mapAttrs'
      nameValuePair
      ;

    # Creates a new nixosSystem with the correct specialArgs, pkgs and name definition
    mkHost = {minimal}: name: let
      pkgs = config.pkgs.x86_64-linux; # FIXME: NOOOOOOOOOOOOOOOOOOOOOOO
    in
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = {
          # Use the correct instance lib that has our overlays
          inherit (pkgs) lib;
          inherit (config) nodes globals;
          inherit inputs minimal;
        };
        modules = [
          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays =
              (import ../pkgs/default.nix inputs)
              ++ [
                inputs.idmail.overlays.default
                # inputs.nixos-cosmic.overlays.default
                inputs.nix-topology.overlays.default
                inputs.nixos-extra-modules.overlays.default
                inputs.nixvim.overlays.default
                inputs.wired-notify.overlays.default
              ];

            node.name = name;
            node.secretsDir = ../hosts/${name}/secrets;
          }
          ../hosts/${name}
        ];
      };

    # Get all folders in hosts/
    hosts = builtins.attrNames (filterAttrs (_: type: type == "directory") (builtins.readDir ../hosts));
  in {
    nixosConfigurations = genAttrs hosts (mkHost {minimal = false;});
    nixosConfigurationsMinimal = genAttrs hosts (mkHost {minimal = true;});

    # True NixOS nodes can define additional guest nodes that are built
    # together with it. We collect all defined guests from each node here
    # to allow accessing any node via the unified attribute `nodes`.
    guestConfigs = flip concatMapAttrs config.nixosConfigurations (_: node:
      flip mapAttrs' (node.config.guests or {}) (
        guestName: guestDef:
          nameValuePair guestDef.nodeName (
            if guestDef.backend == "microvm"
            then node.config.microvm.vms.${guestName}.config
            else node.config.containers.${guestName}.nixosConfiguration
          )
      ));

    # All nixosSystem instanciations are collected here, so that we can refer
    # to any system via nodes.<name>
    nodes = config.nixosConfigurations // config.guestConfigs;
    # Add a shorthand to easily target toplevel derivations
    "@" = mapAttrs (_: v: v.config.system.build.toplevel) config.nodes;
  };
}
