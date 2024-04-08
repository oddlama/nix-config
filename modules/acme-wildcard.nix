{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    assertMsg
    attrNames
    filter
    filterAttrs
    hasInfix
    head
    mkIf
    mkOption
    removeSuffix
    types
    ;

  wildcardDomains = attrNames (filterAttrs (_: v: v.wildcard) config.security.acme.certs);
in {
  options.security.acme.certs = mkOption {
    type = types.attrsOf (types.submodule (submod: {
      options.wildcard = mkOption {
        default = false;
        type = types.bool;
        description = "If set to true, this will automatically append `*.<domain>` to `extraDomainNames`.";
      };

      config.extraDomainNames = mkIf submod.config.wildcard ["*.${submod.config._module.args.name}"];
    }));
  };

  options.services.nginx.virtualHosts = mkOption {
    type = types.attrsOf (types.submodule (submod: {
      options.useACMEWildcardHost = mkOption {
        type = types.bool;
        default = false;
        description = ''Automatically set useACMEHost with the correct wildcard domain for the virtualHosts's main domain.'';
      };
      config = let
        # This retrieves all matching wildcard certs that would include the corresponding domain.
        # If no such domain is found then an assertion is triggered.
        domain = submod.config._module.args.name;
        matchingCerts =
          filter
          (x: !hasInfix "." (removeSuffix ".${x}" domain))
          wildcardDomains;
      in
        mkIf submod.config.useACMEWildcardHost {
          useACMEHost = assert assertMsg (matchingCerts != []) "No wildcard certificate was defined that matches ${domain}";
            head matchingCerts;
        };
    }));
  };
}
