{self, ...} @ inputs: system: let
  pkgs = self.pkgs.${system};
  inherit
    (pkgs.lib)
    nameValuePair
    removeSuffix
    ;
  mkApp = drv: {
    type = "app";
    program = "${drv}";
  };
  args = inputs // {inherit pkgs;};
  apps = [
    ./draw-graph.nix
    ./format-secrets.nix
    ./generate-initrd-keys.nix
    ./generate-wireguard-keys.nix
  ];
in
  builtins.listToAttrs (map (appPath: nameValuePair (removeSuffix ".nix" (builtins.baseNameOf appPath)) (mkApp (import appPath args))) apps)
