{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    assertMsg
    filter
    hasInfix
    head
    mdDoc
    mkIf
    mkOption
    optionals
    removeSuffix
    types
    ;
in {
  options.extra.acme.wildcardDomains = mkOption {
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

  config = {
    lib.extra = {
      # For a given domain, this searches for a matching wildcard acme domain that
      # would include the given domain. If no such domain is defined in
      # extra.acme.wildcardDomains, an assertion is triggered.
      matchingWildcardCert = domain: let
        matchingCerts =
          filter
          (x: !hasInfix "." (removeSuffix ".${x}" domain))
          config.extra.acme.wildcardDomains;
      in
        assert assertMsg (matchingCerts != []) "No wildcard certificate was defined that matches ${domain}";
          head matchingCerts;
    };

    security.acme.certs = lib.genAttrs config.extra.acme.wildcardDomains (domain: {
      extraDomainNames = ["*.${domain}"];
    });

    # Sensible defaults for caddy
    services.caddy = mkIf config.services.caddy.enable {
      extraConfig = ''
        (common) {
          encode zstd gzip

          header {
            # Enable HTTP Strict Transport Security (HSTS)
            Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";

            X-XSS-Protection "1; mode=block"
            X-Frame-Options "DENY"
            X-Content-Type-Options "nosniff"

            # Remove unnecessary information and remove Last-Modified in favor of ETag
            -Server
            -X-Powered-By
            -Last-Modified
          }
        }
      '';
    };

    # Sensible defaults for nginx
    services.nginx = mkIf config.services.nginx.enable {
      recommendedBrotliSettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;

      # SSL config
      sslCiphers = "EECDH+AESGCM:EDH+AESGCM:!aNULL";
      sslDhparam = config.age.secrets."dhparams.pem".path;
      commonHttpConfig = ''
        error_log syslog:server=unix:/dev/log;
        access_log syslog:server=unix:/dev/log;
        ssl_ecdh_curve secp384r1;
      '';
    };

    networking.firewall.allowedTCPPorts =
      optionals
      (config.services.caddy.enable || config.services.nginx.enable)
      [80 443];
  };
}
