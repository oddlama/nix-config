let
  hosts = {
    nom = {
      type = "nixos";
      hostPlatform = "x86_64-linux";
      remoteBuild = true;
    };
    ward = {
      type = "nixos";
      hostPlatform = "x86_64-linux";
      remoteBuild = true;
    };
  };

  inherit (builtins) attrNames concatMap listToAttrs filter;

  filterAttrs = pred: set:
    listToAttrs (concatMap (name: let
      value = set.${name};
    in
      if pred name value
      then [{inherit name value;}]
      else []) (attrNames set));

  removeEmptyAttrs = filterAttrs (_: v: v != {});

  genSystemGroups = hosts: let
    systems = ["aarch64-linux" "x86_64-linux"];
    systemHostGroup = name: {
      inherit name;
      value = filterAttrs (_: host: host.hostPlatform == name) hosts;
    };
  in
    removeEmptyAttrs (listToAttrs (map systemHostGroup systems));

  genTypeGroups = hosts: let
    types = ["homeManager" "nixos"];
    typeHostGroup = name: {
      inherit name;
      value = filterAttrs (_: host: host.type == name) hosts;
    };
  in
    removeEmptyAttrs (listToAttrs (map typeHostGroup types));

  genHostGroups = hosts: let
    all = hosts;
    systemGroups = genSystemGroups all;
    typeGroups = genTypeGroups all;
  in
    all // systemGroups // typeGroups // {inherit all;};
in
  genHostGroups hosts
