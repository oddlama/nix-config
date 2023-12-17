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
  options.security.acme.wildcardDomains = mkOption {
    default = [];
    example = ["example.org"];
    type = types.listOf types.str;
    description = mdDoc ''
      All domains for which a wildcard certificate will be generated.
      This will define the given `security.acme.certs` and set `extraDomainNames` correctly,
      but does not fill any options such as credentials or dnsProvider. These have to be set
      individually for each cert by the user or via `security.acme.defaults`.
    '';
  };

  options.services.nginx.virtualHosts = mkOption {
    type = types.attrsOf (types.submodule (submod: {
      options.useACMEWildcardHost = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc ''Automatically set useACMEHost with the correct wildcard domain for the virtualHosts's main domain.'';
      };
      config = let
        # This retrieves all matching wildcard certs that would include
        # the corresponding domain. If no such domain is defined in
        # security.acme.wildcardDomains, an assertion is triggered.
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
