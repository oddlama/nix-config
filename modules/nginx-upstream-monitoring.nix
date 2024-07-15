{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    attrNames
    filterAttrs
    flip
    mapAttrs'
    mkOption
    nameValuePair
    types
    ;
in {
  options.services.nginx.upstreams = mkOption {
    type = types.attrsOf (types.submodule {
      options.monitoring = {
        enable = mkOption {
          type = types.bool;
          description = "Whether to add a global monitoring entry for this upstream";
          default = false;
        };

        path = mkOption {
          type = types.str;
          description = "The path to query.";
          default = "";
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

        useHttps = mkOption {
          type = types.bool;
          description = "Whether to use https to connect to this upstream when monitoring";
          default = false;
        };

        skipTlsVerification = mkOption {
          type = types.bool;
          description = "Skip tls verification when using https.";
          default = false;
        };
      };
    });
  };

  config = let
    monitoredUpstreams = filterAttrs (_: x: x.monitoring.enable) config.services.nginx.upstreams;
  in {
    globals.monitoring.http = flip mapAttrs' monitoredUpstreams (
      upstreamName: upstream: let
        schema =
          if upstream.monitoring.useHttps
          then "https"
          else "http";
      in
        nameValuePair "${config.node.name}-upstream-${upstreamName}" {
          url = map (server: "${schema}://${server}${upstream.monitoring.path}") (attrNames upstream.servers);
          network = "local-${config.node.name}";
          inherit
            (upstream.monitoring)
            expectedBodyRegex
            expectedStatus
            skipTlsVerification
            ;
        }
    );
  };
}
