{
  self,
  home-manager,
  nixpkgs,
  templates,
  ...
}:
with nixpkgs.lib; let
  homeManagerHosts = filterAttrs (_: x: x.type == "homeManager") self.hosts;
  moduleForHost = hostName: {homeDirectory, ...}: {
    config,
    pkgs,
    ...
  }: {
    imports = [(../hosts + "/${hostName}")];
    nix.registry = {
      nixpkgs.flake = nixpkgs;
      p.flake = nixpkgs;
      pkgs.flake = nixpkgs;
      templates.flake = templates;
    };

    home = {
      inherit homeDirectory;
      sessionVariables.NIX_PATH = concatStringsSep ":" [
        "nixpkgs=${config.xdg.dataHome}/nixpkgs"
        "nixpkgs-overlays=${config.xdg.dataHome}/overlays"
      ];
    };

    xdg = {
      dataFile = {
        nixpkgs.source = nixpkgs;
        overlays.source = ../nix/overlays;
      };
      configFile."nix/nix.conf".text = ''
        flake-registry = ${config.xdg.configHome}/nix/registry.json
      '';
    };
  };

  genConfiguration = hostName: {system, ...} @ attrs:
    home-manager.lib.homeManagerConfiguration {
      pkgs = self.pkgs.${system};
      modules = [(moduleForHost hostName attrs)];
    };
in
  mapAttrs genConfiguration hostManagerHosts
