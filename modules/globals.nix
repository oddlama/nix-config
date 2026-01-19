{
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  defaultOptions = {
    network = mkOption {
      type = types.str;
      description = "The network to which this endpoint is associated.";
    };
  };

  networkOptions = netSubmod: {
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
      default = { };
      type = types.attrsOf (
        types.submodule (hostSubmod: {
          options = {
            id = mkOption {
              type = types.int;
              description = "The id of this host in the network";
            };

            mac = mkOption {
              type = types.nullOr types.net.mac;
              description = "The MAC of this host, if known. May be used to reserve an address in DHCP resolution.";
              default = null;
            };

            ipv4 = mkOption {
              type = types.nullOr types.net.ipv4;
              description = "The IPv4 of this host";
              readOnly = true;
              default =
                if netSubmod.config.cidrv4 == null then
                  null
                else
                  lib.net.cidr.host hostSubmod.config.id netSubmod.config.cidrv4;
            };

            ipv6 = mkOption {
              type = types.nullOr types.net.ipv6;
              description = "The IPv6 of this host";
              readOnly = true;
              default =
                if netSubmod.config.cidrv6 == null then
                  null
                else
                  lib.net.cidr.host hostSubmod.config.id netSubmod.config.cidrv6;
            };

            cidrv4 = mkOption {
              type = types.nullOr types.str; # FIXME: this is not types.net.cidr because it would zero out the host part
              description = "The IPv4 of this host including CIDR mask";
              readOnly = true;
              default =
                if netSubmod.config.cidrv4 == null then
                  null
                else
                  lib.net.cidr.hostCidr hostSubmod.config.id netSubmod.config.cidrv4;
            };

            cidrv6 = mkOption {
              type = types.nullOr types.str; # FIXME: this is not types.net.cidr because it would zero out the host part
              description = "The IPv6 of this host including CIDR mask";
              readOnly = true;
              default =
                if netSubmod.config.cidrv6 == null then
                  null
                else
                  lib.net.cidr.hostCidr hostSubmod.config.id netSubmod.config.cidrv6;
            };
          };
        })
      );
    };
  };
in
{
  options = {
    globals = mkOption {
      default = { };
      type = types.submodule {
        options = {
          root.hashedPassword = mkOption {
            type = types.str;
            description = "My root user's password hash.";
          };

          malte.hashedPassword = mkOption {
            type = types.str;
            description = "My unix password hash.";
          };

          net = mkOption {
            default = { };
            type = types.attrsOf (
              types.submodule (netSubmod: {
                options = networkOptions netSubmod // {
                  vlans = mkOption {
                    default = { };
                    type = types.attrsOf (
                      types.submodule (vlanNetSubmod: {
                        options = networkOptions vlanNetSubmod // {
                          id = mkOption {
                            type = types.ints.between 1 4094;
                            description = "The VLAN id";
                          };

                          name = mkOption {
                            description = "The name of this VLAN";
                            default = vlanNetSubmod.config._module.args.name;
                            type = types.str;
                          };
                        };
                      })
                    );
                  };
                };
              })
            );
          };

          services = mkOption {
            type = types.attrsOf (
              types.submodule {
                options = {
                  domain = mkOption {
                    type = types.str;
                    description = "The domain under which this service can be reached";
                  };
                };
              }
            );
          };

          monitoring = {
            ping = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = defaultOptions // {
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
                  };
                }
              );
            };

            http = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = defaultOptions // {
                    url = mkOption {
                      type = types.either (types.listOf types.str) types.str;
                      description = "The url to connect to.";
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

                    skipTlsVerification = mkOption {
                      type = types.bool;
                      description = "Skip tls verification when using https.";
                      default = false;
                    };
                  };
                }
              );
            };

            dns = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = defaultOptions // {
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
                  };
                }
              );
            };

            tcp = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = defaultOptions // {
                    host = mkOption {
                      type = types.str;
                      description = "The IP/hostname to connect to.";
                    };

                    port = mkOption {
                      type = types.port;
                      description = "The port to connect to.";
                    };
                  };
                }
              );
            };
          };

          mail = {
            domains = mkOption {
              default = { };
              description = "All domains on which we receive mail.";
              type = types.attrsOf (
                types.submodule {
                  options = {
                    public = mkOption {
                      type = types.bool;
                      description = "Whether the domain should be available for use by any user";
                    };
                  };
                }
              );
            };

            primary = mkOption {
              type = types.str;
              description = "The primary mail domain.";
            };
          };

          domains = {
            me = mkOption {
              type = types.str;
              description = "My main domain.";
            };

            personal = mkOption {
              type = types.str;
              description = "My personal domain.";
            };

            company-main = mkOption {
              type = types.str;
              description = "My own company's main domain.";
            };

            company-shop = mkOption {
              type = types.str;
              description = "My own company's shop domain.";
            };
          };

          macs = mkOption {
            default = { };
            type = types.attrsOf types.str;
            description = "Known MAC addresses for external devices.";
          };

          hetzner.storageboxes = mkOption {
            default = { };
            description = "Storage box configurations.";
            type = types.attrsOf (
              types.submodule {
                options = {
                  mainUser = mkOption {
                    type = types.str;
                    description = "Main username for the storagebox";
                  };

                  users = mkOption {
                    default = { };
                    description = "Subuser configurations.";
                    type = types.attrsOf (
                      types.submodule {
                        options = {
                          subUid = mkOption {
                            type = types.int;
                            description = "The subuser id";
                          };

                          path = mkOption {
                            type = types.str;
                            description = "The home path for this subuser (i.e. backup destination)";
                          };
                        };
                      }
                    );
                  };
                };
              }
            );
          };

          # Mirror of the kanidm.persons option.
          kanidm.persons = mkOption {
            description = "Provisioning of kanidm persons";
            default = { };
            type = types.attrsOf (
              types.submodule {
                options = {
                  displayName = mkOption {
                    description = "Display name";
                    type = types.str;
                  };

                  legalName = mkOption {
                    description = "Full legal name";
                    type = types.nullOr types.str;
                    default = null;
                  };

                  mailAddresses = mkOption {
                    description = "Mail addresses. First given address is considered the primary address.";
                    type = types.listOf types.str;
                    default = [ ];
                  };

                  groups = mkOption {
                    description = "List of groups this person should belong to.";
                    type = types.listOf types.str;
                    default = [ ];
                  };
                };
              }
            );
          };
        };
      };
    };
  };
}
