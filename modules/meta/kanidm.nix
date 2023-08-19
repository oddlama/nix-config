{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    assertMsg
    filter
    genAttrs
    hasInfix
    head
    mdDoc
    mkIf
    mkOption
    removeSuffix
    types
    ;
in {
  options.services.kanidm.provision = {
    enable = mkEnableOption "provisioning of systems, groups and users";

    systems = {
    };
  };

  config = {
  };
}
