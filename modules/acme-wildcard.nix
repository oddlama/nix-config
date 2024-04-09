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
    mkIf
    mkOption
    removeSuffix
    types
    ;
in {
  options.security.acme.wildcardDomains = mkOption {
    type = types.listOf types.str;
    default = [];
    description = ''
      List of domains to which a wilcard certificate exists under the same name in `certs`.
      All of these certs will automatically have `*.<domain>` appended to `extraDomainNames`.
    '';
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
          config.security.acme.wildcardDomains;
      in
        mkIf submod.config.useACMEWildcardHost {
          useACMEHost = assert assertMsg (matchingCerts != []) "No wildcard certificate was defined that matches ${domain}";
            head matchingCerts;
        };
    }));
  };

  config.security.acme.certs = genAttrs config.security.acme.wildcardDomains (domain: {
    extraDomainNames = ["*.${domain}"];
  });
}
