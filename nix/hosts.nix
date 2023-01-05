let
  hosts = {
    nom = {
      type = "nixos";
      hostname = "nom";
      hostPlatform = "x86_64-linux";
      remoteBuild = true;
    };
    ward = {
      type = "nixos";
      hostname = "ward";
      hostPlatform = "x86_64-linux";
      remoteBuild = true;
    };
  };

  inherit (builtins) attrNames concatMap listToAttrs;

  filterAttrs = pred: set:
    listToAttrs (concatMap (name: let
      value = set.${name};
    in
      if pred name value
      then [{inherit name value;}]
      else []) (attrNames set));

  systemPred = system: (_: v: builtins.match ".*${system}.*" v.hostPlatform != null);

  genFamily = filter: hosts: rec {
    all = filterAttrs filter hosts;

    nixos = genFamily (_: v: v.type == "nixos") all;
    homeManager = genFamily (_: v: v.type == "home-manager") all;

    linux = genFamily (systemPred "-linux") all;

    aarch64-linux = genFamily (systemPred "aarch64-linux") all;
    x86_64-linux = genFamily (systemPred "x86_64-linux") all;
  };
in
  genFamily (_: _: true) hosts
