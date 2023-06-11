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

  inherit (config.repo.secrets.local) personalDomain;
in {
  options.proxiedDomains = mkOption {
    type = types.attrsOf types.str;
    default = {};
    description = "Registry of relevant proxied domains";
  };

  config.proxiedDomains = {
    grafana = "grafana.${personalDomain}";
    kanidm = "auth.${personalDomain}";
    loki = "loki.${personalDomain}";
  };
}
