{lib, ...}: {
  options.providedDomains = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = {};
    description = "Registry of domains that this host 'provides' (that refer to this host with some functionality). For easy cross-node referencing.";
  };
}
