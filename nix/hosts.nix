with builtins; let
  hosts = {
    nom = {
      type = "nixos";
      system = "x86_64-linux";
    };
    ward = {
      type = "nixos";
      system = "x86_64-linux";
    };
  };

  filterAttrs = pred: set:
    listToAttrs (concatMap (name: let
      value = set.${name};
    in
      if pred name value
      then [{inherit name value;}]
      else []) (attrNames set));

  removeEmptyAttrs = filterAttrs (_: v: v != {});

  # TODO: so much strange shit
  genSystemGroups = hosts: let
    systems = ["aarch64-linux" "x86_64-linux"];
    systemHostGroup = name: {
      inherit name;
      value = filterAttrs (_: host: host.system == name) hosts;
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
