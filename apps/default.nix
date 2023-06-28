{self, ...} @ inputs: system: let
  pkgs = self.pkgs.${system};
  inherit
    (pkgs.lib)
    flip
    nameValuePair
    removeSuffix
    ;
  mkApp = drv: {
    type = "app";
    program = "${drv}";
  };
  args = inputs // {inherit pkgs;};
  apps = [
    ./format-secrets.nix
    ./show-wireguard-qr.nix
  ];
in
  builtins.listToAttrs (flip map apps (
    appPath:
      nameValuePair
      (removeSuffix ".nix" (builtins.baseNameOf appPath))
      (mkApp (import appPath args))
  ))
