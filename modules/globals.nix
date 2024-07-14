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
          };

          monitoring = {
            ping = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  hostv4 = mkOption {
                    type = types.nullOr types.str;
                    description = "The IP/hostname to ping via ipv4.";
                    default = null;
                  };

                  hostv6 = mkOption {
                    type = types.nullOr types.str;
                    description = "The IP/hostname to ping via ipv6.";
                    default = null;
                  };

                  location = mkOption {
                    type = types.str;
                    description = "A location tag added to this metric.";
                  };

                  network = mkOption {
                    type = types.str;
                    description = "The network to which this endpoint is associated.";
                  };
                };
              });
            };

            http = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  url = mkOption {
                    type = types.str;
                    description = "The url to connect to.";
                  };

                  location = mkOption {
                    type = types.str;
                    description = "A location tag added to this metric.";
                  };

                  network = mkOption {
                    type = types.str;
                    description = "The network to which this endpoint is associated.";
                  };

                  expectedStatus = mkOption {
                    type = types.int;
                    default = 200;
                    description = "The HTTP status code to expect.";
                  };

                  expectedBodyRegex = mkOption {
                    type = types.nullOr types.str;
                    description = "A regex pattern to expect in the body.";
                    default = null;
                  };
                };
              });
            };

            dns = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  server = mkOption {
                    type = types.str;
                    description = "The DNS server to query.";
                  };

                  domain = mkOption {
                    type = types.str;
                    description = "The domain to query.";
                  };

                  record-type = mkOption {
                    type = types.str;
                    description = "The record type to query.";
                    default = "A";
                  };

                  location = mkOption {
                    type = types.str;
                    description = "A location tag added to this metric.";
                  };

                  network = mkOption {
                    type = types.str;
                    description = "The network to which this endpoint is associated.";
                  };
                };
              });
            };

            tcp = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  host = mkOption {
                    type = types.str;
                    description = "The IP/hostname to connect to.";
                  };

                  port = mkOption {
                    type = types.port;
                    description = "The port to connect to.";
                  };

                  location = mkOption {
                    type = types.str;
                    description = "A location tag added to this metric.";
                  };

                  network = mkOption {
                    type = types.str;
                    description = "The network to which this endpoint is associated.";
                  };
                };
              });
            };
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
