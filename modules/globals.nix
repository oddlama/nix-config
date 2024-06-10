{
  lib,
  options,
  ...
}: let
  inherit
    (lib)
    mkOption
    types
    ;
in {
  options = {
    globals = mkOption {
      default = {};
      type = types.submodule {
        options = {
          net = mkOption {
            type = types.attrsOf (types.submodule (netSubmod: {
              options = {
                cidrv4 = mkOption {
                  type = types.nullOr types.net.cidrv4;
                  description = "The CIDRv4 of this network";
                  default = null;
                };

                cidrv6 = mkOption {
                  type = types.nullOr types.net.cidrv6;
                  description = "The CIDRv6 of this network";
                  default = null;
                };

                hosts = mkOption {
                  type = types.attrsOf (types.submodule (hostSubmod: {
                    options = {
                      id = mkOption {
                        type = types.int;
                        description = "The id of this host in the network";
                      };

                      ipv4 = mkOption {
                        type = types.nullOr types.net.ipv4;
                        description = "The IPv4 of this host";
                        readOnly = true;
                        default =
                          if netSubmod.config.cidrv4 == null
                          then null
                          else lib.net.cidr.host hostSubmod.config.id netSubmod.config.cidrv4;
                      };

                      ipv6 = mkOption {
                        type = types.nullOr types.net.ipv6;
                        description = "The IPv6 of this host";
                        readOnly = true;
                        default =
                          if netSubmod.config.cidrv6 == null
                          then null
                          else lib.net.cidr.host hostSubmod.config.id netSubmod.config.cidrv6;
                      };

                      cidrv4 = mkOption {
                        type = types.nullOr types.str; # FIXME: this is not types.net.cidr because it would zero out the host part
                        description = "The IPv4 of this host including CIDR mask";
                        readOnly = true;
                        default =
                          if netSubmod.config.cidrv4 == null
                          then null
                          else lib.net.cidr.hostCidr hostSubmod.config.id netSubmod.config.cidrv4;
                      };

                      cidrv6 = mkOption {
                        type = types.nullOr types.str; # FIXME: this is not types.net.cidr because it would zero out the host part
                        description = "The IPv6 of this host including CIDR mask";
                        readOnly = true;
                        default =
                          if netSubmod.config.cidrv6 == null
                          then null
                          else lib.net.cidr.hostCidr hostSubmod.config.id netSubmod.config.cidrv6;
                      };
                    };
                  }));
                };
              };
            }));
          };

          services = mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                domain = mkOption {
                  type = types.str;
                  description = "The domain under which this service can be reached";
                };
              };
            });

            #telegrafChecks = mkOption {
            #  type = types.attrsOf (types.submodule {
            #    options = {
            #      domain = mkOption {};
            #    };
            #  });
            #};
          };
        };
      };
    };

    _globalsDefs = mkOption {
      type = types.unspecified;
      default = options.globals.definitions;
      readOnly = true;
      internal = true;
    };
  };
}
