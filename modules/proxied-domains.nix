{lib, ...}: {
  options.proxiedDomains = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = {};
    description = "Registry of proxied domains for easy cross-node referencing.";
  };
}
