{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mdDoc
    mkDefault
    mkOption
    types
    ;

  cfg = config.node;
in {
  options.node = {
    name = mkOption {
      description = mdDoc "A unique name for this node (host) in the repository. Defines the default hostname, but this can be overwritten.";
      type = types.str;
    };

    secretsDir = mkOption {
      description = mdDoc "Path to the secrets directory for this node.";
      type = types.path;
    };
  };

  config = {
    networking.hostName = mkDefault config.node.name;
  };
}
