{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkOption
    types
    ;
in {
  options.node = {
    name = mkOption {
      description = "A unique name for this node (host) in the repository. Defines the default hostname, but this can be overwritten.";
      type = types.str;
    };

    secretsDir = mkOption {
      description = "Path to the secrets directory for this node.";
      type = types.path;
    };
  };

  config = {
    networking.hostName = config.node.name;
  };
}
